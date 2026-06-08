/*
 * nec260.c - NEC CDR-260 driver
 *  some pieces derived from mcd.c.
 *
 * scott snyder  <snyder@fnald0.fnal.gov>
 *
 *   0.1  May 31, 1994  Initial alpha release.
 *   0.2  Sep  4, 1994  Converted into a loadable kernel module.
 *                      Made more flexible wrt. hardware configurations.
 *                      Sense disk changes properly.
 *   0.3  Sep. 11, 1994 Add LINKED_IN_KERNEL #ifdef's.
 *
 *   Copyright (c) 1994  scott snyder <snyder@fnald0.fnal.gov>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2, or (at your option)
 *   any later version.
 *
 *   You should have received a copy of the GNU General Public License
 *   (for example /usr/src/linux/COPYING); if not, write to the Free
 *   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#define REALLY_SLOW_IO
#include <asm/io.h>

#include <linux/string.h>
#include <linux/sched.h>
#include <linux/timer.h>
#include <asm/io.h>
#include <linux/hdreg.h>
#include <linux/signal.h>
#include <linux/autoconf.h>

#ifdef LINKED_IN_KERNEL
# define MAYBE_STATIC static
#else
# include <linux/module.h>
# define MAYBE_STATIC
#endif

#include "version.h"

/***************************************************************************/

/* Configuration options which may be set when loading the driver. */

/* Major device number. */
MAYBE_STATIC int nec260_major = 26;

/* IRQ level used.  Only matters if nec260_no_hd is turned on. */
MAYBE_STATIC int nec260_irq = 14;

/* Base I/O address for the IDE adapter registers. */
MAYBE_STATIC int nec260_base = HD_DATA;

/* Set this to 1 if the device is configured as the master on the bus. */
MAYBE_STATIC int nec260_master = 0;
 
/* Set this to 1 if the cdrom drive is on the bus by itself. */
MAYBE_STATIC int nec260_no_hd = 0;

/***************************************************************************/

#define HD_DATA_OFFSET    (HD_DATA   - HD_DATA)
#define HD_STATUS_OFFSET  (HD_STATUS - HD_DATA)
#define HD_ERROR_OFFSET   (HD_ERROR  - HD_DATA)
#define HD_LCYL_OFFSET    (HD_LCYL   - HD_DATA)
#define HD_HCYL_OFFSET    (HD_HCYL   - HD_DATA)
#define HD_CURRENT_OFFSET (HD_CURRENT - HD_DATA)
#define HD_COMMAND_OFFSET (HD_COMMAND - HD_DATA)

#define MAJOR_NR nec260_major
#define DEVICE_NAME "NEC IDE CD-ROM"
#define DEVICE_REQUEST do_nec260_request
#define DEVICE_NR(device) (MINOR(device))
#define DEVICE_ON(device)
#define DEVICE_OFF(device)
#define DEVICE_INTR do_nec260

#include "blk.h"

/* The call interface for binding interrupts changed in 1.1.43 :-( */

#if (KERNEL_MAJOR >= 1) && \
    (KERNEL_MINOR >= 1) && \
    (KERNEL_PATCH >= 43)
# define NO_IRQACTION
#endif

/***************************************************************************/

/* special command codes for strategy routine. */
#define CHECK_STATUS 4314

#define CD_BLOCK_SIZE 2048

static void nec260_timeout (unsigned long x);
static void do_read_callback (void);
static void do_read_callback_2 (void);
static int test_read (unsigned int dev, unsigned int block,
		      unsigned int nsect);


/* Values to write to the controller registers to start a transaction. */

static char regimage[7] = {
  0,                          /* HD_PRECOMP */
  0,                          /* HD_NSECTOR */
  0,                          /* HD_SECTOR  */
  (CD_BLOCK_SIZE & 0xff),     /* HD_LCYL   # of bytes to read  (lo) */
  (CD_BLOCK_SIZE >> 8),       /* HD_HCYL   # of bytes to read  (hi) */
  0xf0,                       /* HD_CURRENT   (device select) (slave)     */
  0xa0                        /* HD_COMMAND                         */
};


/* Image of command to be sent to the device for a read.
   Portions of this will be overwritten to set the sector number.
   If i actually had documentation for this device, i could probably
   give these values some meaningful names... */

static char cmdimage[12] = {0x28, 0, 0, 0, 0x0f, 0x54, 0, 0, 1, 0, 0, 0};

static int nec260_request_in_progress = 0;
static int nec260_waiting_for_int = 0;
static int nec260_open_count = 0;
static int nec260_media_changed = 0;
static void (**nec260_handler_ptr)(void);
static int the_hd_major;
static int retrying = 0;

static struct timer_list nec260_timer = {NULL, NULL, 0, 0, nec260_timeout};

/* The transfer buffer. */
static char nec260_buf[CD_BLOCK_SIZE];
static int  nec260_bn = -1;

/* The dummy request which we use to plug up the HD queue. */
static struct request plug;

/* Symbols from hd.c. */
extern int the_nec260_major;
extern void (*do_hd)(void);
#ifdef CONFIG_BLK_DEV_HD1
extern void (*do_hd1)(void);
#endif


/***************************************************************************/

/*
 * Wait until the controller is idle.
 * Returns the status field; if it has the bit BUSY_STAT set,
 * we timed out.
 */
static int controller_busy (void)
{
  int retries = 100000;
  unsigned char status;

  do 
    {
      status = inb_p (nec260_base + HD_STATUS_OFFSET);
    } while ((status & BUSY_STAT) && --retries);
#ifdef SHY_DEVICE
  {
    static doneonce = 0;
    if (status == 0xff && !doneonce)
      status = 0;
    doneonce = 1;
  }
#endif
  return status;
}


/*
 * Wait for the controller to be ready to receive a command.
 * Returns 0 if successful, -1 if we timed out.
 */
static inline int wait_DRQ (void)
{
  int retries = 100000;

  while (--retries > 0)
    if (inb_p (nec260_base + HD_STATUS_OFFSET) & DRQ_STAT)
      return 0;
  return -1;
}


/*
 * Stick a dummy request at the head of the HD request queue
 * to prevent any HD activity while we're using the controller.
 * The HD queue must be empty.
 */
static void plug_hd (void)
{
  if (nec260_no_hd)
    printk ("nec260: spurious call to plug_hd\n");
  else
    { 
      cli ();  /* safety */
      if (blk_dev[the_hd_major].current_request != NULL)
	{
	  printk ("nec260 (plug_hd): hd already active!\n");
	  return;
	}
      blk_dev[the_hd_major].current_request = &plug;
      plug.dev = -1;
      plug.next = NULL;
      
      /* exits with ints clear */
    }
}


/*
 * Remove the dummy request from the start of the HD queue.
 */
static void unplug_hd (void)
{
  if (nec260_no_hd)
    printk ("nec260: spurious call to unplug_hd\n");
  else
    { 
      cli ();  /* safety */
      if (blk_dev[the_hd_major].current_request != &plug) 
	{
	  printk ("nec260 (unplug_hd): hd not plugged!\n");
	  return;
	}
      blk_dev[the_hd_major].current_request = plug.next;
      (blk_dev[the_hd_major].request_fn) ();
    }
}


/*
 * Unplug the HD queue and end a idecd request.
 */
static void end_read_request (int flag)
{
  if (! nec260_no_hd)
    unplug_hd ();
  end_request (flag);
  nec260_request_in_progress = 0;
}


/*
 * Transfer as much data as we can from NEC260_BUF to the output buffer.
 */
static void
nec260_transfer(void)
{
  long offs;

  while (CURRENT -> nr_sectors > 0 && nec260_bn == CURRENT -> sector / 4)
    {
      offs = (CURRENT -> sector & 3) * 512;
      memcpy (CURRENT -> buffer, nec260_buf + offs, 512);
      CURRENT -> nr_sectors--;
      CURRENT -> sector++;
      CURRENT -> buffer += 512;
    }
}


/*
 * Invalidate any data saved in our internal buffer
 */
static void
nec260_invalidate_buffers (void)
{
  nec260_bn = -1;
}


/*
 * Complete a read request with status STAT, and call the request routine
 * to start off the next one.
 */
static void complete_read_request (int stat)
{
  del_timer (&nec260_timer);	/* Cancel the timeout */
  end_read_request (stat);
  cli ();
  do_nec260_request ();
}


/*
 * Called when our timer goes off.
 */
static void nec260_timeout (unsigned long x)
{
  /* Ignore if we're not waiting for an interrupt. */
  if (! nec260_waiting_for_int) return;

  /* Complete the request with error status. */
  nec260_waiting_for_int = 0;
  printk ("nec260: request timed out\n");
  if (*nec260_handler_ptr == do_read_callback ||
      *nec260_handler_ptr == do_read_callback_2)
    *nec260_handler_ptr = NULL;
  else
    printk ("nec260: funny value for interrupt handler\n");
  complete_read_request (0);
}

/*
 * Interrupt routine to swallow the extra interrupt from the device.
 */
static void do_read_callback_2 (void)
{
  int stat;

  *nec260_handler_ptr = NULL;

  if (! nec260_waiting_for_int) 
    {
      printk ("nec260 (do_read_callback_2): spurious call?\n");
      return;
    }

  nec260_waiting_for_int = 0;

  /* Check error flag and complete the I/O. */
  stat = inb (nec260_base + HD_ERROR_OFFSET);
  stat = ((stat & ERR_STAT) == 0);
  complete_read_request (stat);
}


/*
 * Interrupt routine.  Called when a read request has completed.
 */
static void do_read_callback (void)
{
  int stat, len, thislen;

  if (! nec260_waiting_for_int) 
    {
      printk ("nec260 (do_read_callback): spurious call?\n");
      return;
    }

  nec260_waiting_for_int = 0;

  /* Check for errors. */
  stat = inb (nec260_base + HD_ERROR_OFFSET);

  if (stat & ERR_STAT)
    stat = 0;
  else
    {
      if (CURRENT->cmd != CHECK_STATUS)
	{
	  /* Error bit not set.
	     Read the device registers to see how much data is waiting. */
	  len = inb_p (nec260_base + HD_LCYL_OFFSET) +
	           256 * inb_p (nec260_base + HD_HCYL_OFFSET);

	  /* Read the data into our buffer. */
	  thislen = len;
	  if (thislen > sizeof (nec260_buf)) thislen = sizeof (nec260_buf);
	  insw (nec260_base + HD_DATA_OFFSET, nec260_buf, thislen/2);
	  len -= thislen;

	  /* Warn if the size of the data from the device is
	     larger than the buffer. */
	  if (len > 0)
	    {
	      printk ("nec260: discarding %x bytes\n", len);
	      while (len > 0) 
		{
		  (void) inw_p (nec260_base + HD_DATA_OFFSET);
		  len -= 2;
		}
	    }
	}

      /* Check for tray open/disk changed.
	 For some reason, these don't set the `error' bit. */
      if (stat == 0x24)
	{
	  /* Tray open.  The request fails. */
	  printk ("nec260: tray open\n");
	  nec260_invalidate_buffers ();
	  nec260_media_changed = 1;
	  stat = 0;
	}
      else if (stat == 0x64)
	{
	  /* Media changed.  Try the operation again. */
	  printk ("nec260: media change\n");
	  nec260_invalidate_buffers ();
	  nec260_media_changed = 1;
	  if (CURRENT->cmd != CHECK_STATUS && !retrying)
	    {
	      del_timer (&nec260_timer);
	      retrying = 1;
	      test_read (MINOR (CURRENT->dev),
			 CURRENT->sector, CURRENT->nr_sectors);
	      return;
	    }
	  stat = 0;
	}
      else if (CURRENT->cmd == CHECK_STATUS)
	stat = 1;
      else
	{
	  /* Copy as much as we can into the output buffer. */
	  nec260_bn = CURRENT->sector / 4;
	  nec260_transfer ();

	  stat = 1;
	}
    }

  /* If there was an error, complete the request now with an error.
     But if the read is successful, the device is going to be sending
     us another interrupt.  It likes long goodbyes, i guess.  Anyway,
     wait until we see this extra interrupt before ending the request. */
  if (stat && CURRENT->cmd != CHECK_STATUS)
    {
      *nec260_handler_ptr = do_read_callback_2;
      nec260_waiting_for_int = 1;
    }
  else
    complete_read_request (stat);
}
 

/*
 * Start a read request from the CD-ROM.
 * Returns 0 if the request was started successfully,
 *  -1 if there was an error.
 * Note: The NSECT arg is presently ignored; we always read exactly
 *       one block.
 */
static int do_read (unsigned int dev, unsigned int block, unsigned int nsect)
{
  int i;
  char *the_regimage;
  char check_status_regimage[sizeof (regimage)];
  char *the_cmdimage;
  char check_status_cmdimage[sizeof (cmdimage)];

  /* Wait for the controller to be idle. */
  if (controller_busy () & BUSY_STAT) return -1;

  if (CURRENT->cmd == CHECK_STATUS)
    {
      the_regimage = check_status_regimage;
      for (i=0; i<sizeof (check_status_regimage); i++)
	check_status_regimage[i] = 0;
      check_status_regimage[HD_CURRENT_OFFSET-1]=regimage[HD_CURRENT_OFFSET-1];
      check_status_regimage[HD_COMMAND_OFFSET-1]=regimage[HD_COMMAND_OFFSET-1];
    }
  else
    the_regimage = regimage;

  /* Set up the controller registers. */
  for (i=0; i<sizeof (regimage); i++)
    outb_p (the_regimage[i], nec260_base + HD_ERROR_OFFSET + i);

  /* Wait for the controller to be ready to receive the comand. */
  if (controller_busy () & BUSY_STAT) {
    printk ("nec260: controller busy\n"); return -1;
  }
  if (wait_DRQ ()) {
    printk ("nec260: controller not ready\n"); return -1;
  }
  if (controller_busy () & BUSY_STAT) {
    printk ("nec260: controller busy (2)\n"); return -1;
  }

  if (CURRENT->cmd == CHECK_STATUS)
    {
      the_cmdimage = check_status_cmdimage;
      for (i=0; i<sizeof (check_status_cmdimage); i++)
	check_status_cmdimage[i] = 0;
    }
  else
    {
      /* Write the sector address into the command image. */
      {
	union {
	  struct {unsigned char b0, b1, b2, b3;} b;
	  struct {unsigned long l0;} l;
	} conv;
	conv.l.l0 = CURRENT->sector / 4;
	cmdimage[2] = conv.b.b3;
	cmdimage[3] = conv.b.b2;
	cmdimage[4] = conv.b.b1;
	cmdimage[5] = conv.b.b0;
      }
      the_cmdimage = cmdimage;
    }

  /* Send the command to the device. */
  outsw (nec260_base + HD_DATA_OFFSET, the_cmdimage, sizeof (cmdimage)/2);

  /* Set up our interrupt handler and return. */
  *nec260_handler_ptr = do_read_callback;
  nec260_waiting_for_int = 1;

  /* Set up a timeout. */
  nec260_timer.expires = 500;
  add_timer (&nec260_timer);

  return 0;
}


/*
 * Start a read request.
 * If there is an error starting it, terminate the current request
 * immediately with an error.
 */
static int test_read (unsigned int dev, unsigned int block,
		      unsigned int nsect)
{
  int stat;
  stat = do_read (dev, block, nsect);

  if (stat)
    end_read_request (0);
  return 1;
}


/*
 * I/O request routine called from kernel.
 */
static void do_nec260_request (void)
{
  unsigned int block,dev;
  unsigned int nsect;

  /* Don't do anything if we're waiting for a request to complete.
     (Can this actually happen?) */
  if (nec260_request_in_progress) return;

 repeat:
  cli (); /* safety */
  nec260_request_in_progress = 0;

  /* Return if our queue is plugged. */
  if (!(CURRENT) || CURRENT->dev < 0) return;

  /* Get the next request on the queue. */
  INIT_REQUEST;
  dev = MINOR (CURRENT->dev);
  block = CURRENT->sector;
  nsect = CURRENT->nr_sectors;

  /* Return if there wasn't one. */
  if (CURRENT == NULL || CURRENT -> sector == -1)
    return;

  /* We can only read. */
  if (CURRENT -> cmd != READ && CURRENT->cmd != CHECK_STATUS)
    {
      printk ("nec260: bad cmd %d\n", CURRENT -> cmd);
      end_request (0);
      goto repeat;
    }

  if (CURRENT->cmd != CHECK_STATUS)
    {
      /* Try to satisfy the request from the buffer. */
      nec260_transfer ();

      /* If we got the entire request, we're done. */
      if (CURRENT->nr_sectors == 0) 
	{
	  end_request (1);
	  goto repeat;
	}
    }

  /* If the HD is currently active,  return - we must wait for it to finish.
     If it is idle (no requests in the queue), plug up the queue with a dummy
     request until we're done using the controller. */
  if (! nec260_no_hd)
    {
      if (blk_dev[the_hd_major].current_request) return;
      plug_hd ();
    }
  nec260_request_in_progress = 1;

  retrying = 0;
  if (!test_read (dev, block, nsect))
    goto repeat;

  sti ();
  return;
}


/*
 * Open the device.
 */

static int
nec260_open (struct inode *ip, struct file *fp)
{
  /* should check that h/w is available... */

  /* no write access */
  if (fp->f_mode & 2) return -EROFS;

  if (!nec260_open_count)
    {
      nec260_invalidate_buffers ();

      /* should check that there's a disk in the drive? */
    }

  /* Opened ok.  Count this access and return success. */
  ++nec260_open_count;
#ifndef LINKED_IN_KERNEL
  MOD_INC_USE_COUNT;
#endif
  return 0;
}


/*
 * Close down the device.  Invalidate all cached blocks.
 */

static void
nec260_release (struct inode *inode, struct file *file)
{
  --nec260_open_count;
  if (nec260_open_count < 0)
    {
      printk ("nec260: inconsistent open count %d\n", nec260_open_count);
      nec260_open_count = 0;
    }

  if (nec260_open_count == 0)
    {
      nec260_invalidate_buffers ();
      sync_dev (inode->i_rdev);
      invalidate_buffers (inode->i_rdev);
    }
#ifndef LINKED_IN_KERNEL
  MOD_DEC_USE_COUNT;
#endif
}


static
void nec260_do_check_status (dev_t full_dev)
{
  struct request check_status_req;
  struct semaphore sem = MUTEX_LOCKED;

  check_status_req.dev = full_dev;
  check_status_req.cmd = CHECK_STATUS;
  check_status_req.errors = 0;
  check_status_req.sector = 0;
  check_status_req.nr_sectors = 0;
  check_status_req.current_nr_sectors = 0;
  check_status_req.buffer = NULL;
  check_status_req.sem = &sem;
  check_status_req.bh = NULL;
  check_status_req.bhtail = NULL;
  check_status_req.next = NULL;

  cli ();
  if (CURRENT == NULL)
    {
      CURRENT = &check_status_req;
      do_nec260_request ();
    }
  else
    {
      check_status_req.next = CURRENT;
      CURRENT->next = &check_status_req;
    }
  sti ();

  down (&sem);
}


static
int nec260_disk_change (dev_t full_dev)
{
  int retval, target;

  target = MINOR (full_dev);

  if (target > 0)
    {
      printk ("nec260 (nec260_disk_change): invalid device %d\n", target);
      return 0;
    }

  if (nec260_media_changed == 0)
    nec260_do_check_status (full_dev);

  retval = nec260_media_changed;
  nec260_media_changed = 0;

  printk ("nec260: disk change %d\n", retval);

  return retval;
}


static void nec260_interrupt (int unused)
{
  void (*handler)(void) = DEVICE_INTR;
	
  DEVICE_INTR = NULL;
  if (!handler)
    printk ("nec260: unexpected interrupt\n");
  else
    handler();
  sti();
}


#ifndef NO_IRQACTION
/*
 * This is the cdrom IRQ description. The SA_INTERRUPT in sa_flags
 * means we run the IRQ-handler with interrupts disabled.
 */
static struct sigaction nec260_sigaction = {
	nec260_interrupt,
	0,
	SA_INTERRUPT,
	NULL
};
#endif /* ! NO_IRQACTION */



static struct file_operations nec260_fops = {
	NULL,			/* lseek - default */
	block_read,		/* read - general block-dev read */
	block_write,		/* write - general block-dev write */
	NULL,			/* readdir - bad */
	NULL,			/* select */
	NULL, 			/* ioctl */
	NULL,			/* mmap */
	nec260_open,		/* open */
        nec260_release,		/* release */
        NULL,	                /* fsync */  
        NULL,	                /* fasync */  
        nec260_disk_change,	/* check_media_change */  
        NULL,	                /* revalidate */  
};


MAYBE_STATIC int init_module (void)
{
  /* Find the major numbe of the HD on our IDE bus. */
  the_hd_major = HD_MAJOR;
#ifdef CONFIG_BLK_DEV_HD1
  if (nec260_base == HD1_DATA)
    the_hd_major = HD1_MAJOR;
#endif

  /* Register ourselves with the kernel. */
  if (register_blkdev (nec260_major, "nec260", &nec260_fops) != 0) 
    {
      printk("nec260: Unable to get major %d for NEC CDR-260\n", nec260_major);
      return -EIO;
    }

  printk ("nec260: registered with major #%d\n", nec260_major);

  /* Install our device request routine. */
  blk_dev[nec260_major].request_fn = DEVICE_REQUEST;
  read_ahead[nec260_major] = 4;

  /* Set the proper device select code. */
  if (nec260_master)
    regimage[5] = 0xe0;
  else
    regimage[5] = 0xf0;

  if (nec260_no_hd)
    {
      /* Set up the interrupt. */
      do_nec260 = NULL;
      nec260_handler_ptr = &do_nec260;
#ifdef NO_IRQACTION
      if (request_irq (nec260_irq, nec260_interrupt, SA_INTERRUPT, "nec260"))
#else
      if (irqaction (nec260_irq, &nec260_sigaction))
#endif
	{
	  printk ("Unable to get IRQ%d for NEC CDR-260 CD-ROM\n", nec260_irq);
	  unregister_blkdev (nec260_major, "nec260");
	  return -EIO;
	}
    }
  else
    {
      /* tell hd.c our major number */
      the_nec260_major = nec260_major;

      /* Set up nec260_handler_ptr to point to the HD interrupt vector. */
      nec260_handler_ptr = &do_hd;
#ifdef CONFIG_BLK_DEV_HD1
      if (nec260_base == HD1_DATA)
	the_hd_major = &do_hd1;
#endif
    }

  return 0;
}

#ifdef LINKED_IN_KERNEL

unsigned long nec260_init (unsigned long mem_start, unsigned long mem_end)
{
  init_module ();
  return mem_start;
}

#else

void cleanup_module (void)
{
  if (MOD_IN_USE)
    printk("nec260: device busy, remove delayed\n");

  if (unregister_blkdev (nec260_major, "nec260") != 0)
    printk ("nec260: cleanup_module failed\n");
  else 
    {
      printk ("nec260: cleanup_module succeeded\n");
      if (nec260_no_hd)
	free_irq (nec260_irq);
      else
	the_nec260_major = 0;
    }
}

#endif
