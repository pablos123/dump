# Compilation of NACHOS comments with added information.

## main.cc

```C++
/// Bootstrap code to initialize the operating system kernel.
///
/// Allows direct calls into internal operating system functions, to simplify
/// debugging and testing.  In practice, the bootstrap code would just
/// initialize data structures, and start a user program to print the login
/// prompt.
```

**Bootstrapping:** In general, bootstrapping usually refers to a self-starting process that is supposed to continue or grow without external input.

## thread.hh/thread.cc

```C++
/// Data structures for managing threads.
///
/// A thread represents sequential execution of code within a program.  So
/// the state of a thread includes the program counter, the processor
/// registers, and the execution stack.
///
/// Note that because we allocate a fixed size stack for each thread, it is
/// possible to overflow the stack -- for instance, by recursing to too deep
/// a level.  The most common reason for this occuring is allocating large
/// data structures on the stack.  For instance, this will cause problems:
///
///     void foo() { int buf[1000]; ...}
///
/// Instead, you should allocate all data structures dynamically:
///
///     void foo() { int *buf = new int [1000]; ...}
///
/// Bad things happen if you overflow the stack, and in the worst case, the
/// problem may not be caught explicitly.  Instead, the only symptom may be
/// bizarre segmentation faults.  (Of course, other problems can cause seg
/// faults, so that is not a sure sign that your thread stacks are too
/// small.)
///
/// One thing to try if you find yourself with segmentation faults is to
/// increase the size of thread stack -- `STACK_SIZE`.
///
/// In this interface, forking a thread takes two steps.  We must first
/// allocate a data structure for it:
///     t = new Thread
/// Only then can we do the fork:
///     t->Fork(f, arg)


/// Every thread has:
/// * an execution stack for activation records (`stackTop` and `stack`);
/// * space to save CPU registers while not running (`machineState`);
/// * a `status` (running/ready/blocked).
///
///  Some threads also belong to a user address space; threads that only run
///  in the kernel have a null address space.

/// User-level CPU register state.
/// A thread running a user program actually has *two* sets of CPU
/// registers -- one for its state while executing user code, one for its
/// state while executing kernel code.    

/// First frame on thread execution stack.
///
/// 1. Enable interrupts.
/// 2. Call `func`.
/// 3. (When func returns, if ever) call `ThreadFinish`.
void ThreadRoot();

/// De-allocate a thread.
///
/// NOTE: the current thread *cannot* delete itself directly, since it is
/// still running on the stack that we need to delete.
///
/// NOTE: if this is the main thread, we cannot delete the stack because we
/// did not allocate it -- we got it automatically as part of starting up
/// Nachos.
/// Check a thread's stack to see if it has overrun the space that has been
/// allocated for it.  If we had a smarter compiler, we would not need to
/// worry about this, but we do not.
Thread::~Thread(){}

/// NOTE: Nachos will not catch all stack overflow conditions.  In other
/// words, your program may still crash because of an overflow.
///
/// If you get bizarre results (such as seg faults where there is no code)
/// then you *may* need to increase the stack size.  You can avoid stack
/// overflows by not putting large data structures on the stack.  Do not do
/// this:
///         void foo() { int bigArray[10000]; ... }
void Thread::CheckOverflow() const {...}

/// Called by `ThreadRoot` when a thread is done executing the forked
/// procedure.
///
/// NOTE: we do not immediately de-allocate the thread data structure or the
/// execution stack, because we are still running in the thread and we are
/// still on the stack!  Instead, we set `threadToBeDestroyed`, so that
/// `Scheduler::Run` will call the destructor, once we are running in the
/// context of a different thread.
///
/// NOTE: we disable interrupts, so that we do not get a time slice between
/// setting `threadToBeDestroyed`, and going to sleep.
void Thread::Finish(int st){}

/// Relinquish the CPU if any other thread is ready to run.
///
/// If so, put the thread on the end of the ready list, so that it will
/// eventually be re-scheduled.
///
/// NOTE: returns immediately if no other thread on the ready queue.
/// Otherwise returns when the thread eventually works its way to the front
/// of the ready list and gets re-scheduled.
///
/// NOTE: we disable interrupts, so that looking at the thread on the front
/// of the ready list, and switching to it, can be done atomically.  On
/// return, we re-set the interrupt level to its original state, in case we
/// are called with interrupts disabled.
///
/// Similar to `Thread::Sleep`, but a little different.
void Thread::Yield(){}

/// Relinquish the CPU, because the current thread is blocked waiting on a
/// synchronization variable (`Semaphore`, `Lock`, or `Condition`).
/// Eventually, some thread will wake this thread up, and put it back on the
/// ready queue, so that it can be re-scheduled.
///
/// NOTE: if there are no threads on the ready queue, that means we have no
/// thread to run.  `Interrupt::Idle` is called to signify that we should
/// idle the CPU until the next I/O interrupt occurs (the only thing that
/// could cause a thread to become ready to run).
///
/// NOTE: we assume interrupts are already disabled, because it is called
/// from the synchronization routines which must disable interrupts for
/// atomicity.  We need interrupts off so that there cannot be a time slice
/// between pulling the first thread off the ready list, and switching to it.
void Thread::Sleep(bool consoleRunning){}
```

## semaphore.hh/semaphore.cc

```C++
/// Semaphores offer only two operations:
///
/// * `P` -- wait until `value > 0`, then decrement `value`.
/// * `V` -- increment `value`, awaken a waiting thread if any.
///
/// Observe that this interface does *not* allow to read the semaphore value
/// directly -- even if you were able to read it, it would serve for nothing,
/// because meanwhile another thread could have modified the semaphore, in
/// case you have lost the CPU for some time.


/// Routines for synchronizing threads.
///
/// This is the only implementation of a synchronizing primitive that comes
/// with base Nachos.
///
/// Any implementation of a synchronization routine needs some primitive
/// atomic operation.  We assume Nachos is running on a uniprocessor, and
/// thus atomicity can be provided by turning off interrupts.  While
/// interrupts are disabled, no context switch can occur, and thus the
/// current thread is guaranteed to hold the CPU throughout, until interrupts
/// are reenabled.
///
/// Because some of these routines might be called with interrupts already
/// disabled (`Semaphore::V` for one), instead of turning on interrupts at
/// the end of the atomic operation, we always simply re-set the interrupt
/// state back to its original value (whether that be disabled or enabled).
```

## interrupt.hh/interrupt.cc

```C++
/// Data structures to emulate low-level interrupt hardware.
///
/// The hardware provides a routine (`SetLevel`) to enable or disable
/// interrupts.
///
/// In order to emulate the hardware, we need to keep track of all interrupts
/// the hardware devices would cause, and when they are supposed to occur.
///
/// This module also keeps track of simulated time.  Time advances
/// only when the following occur:
///
/// * interrupts are re-enabled;
/// * a user instruction is executed;
/// * there is nothing in the ready queue.
///
/// As a result, unlike real hardware, interrupts (and thus time-slice
/// context switches) cannot occur anywhere in the code where interrupts are
/// enabled, but rather only at those places in the code where simulated time
/// advances (so that it becomes time to invoke an interrupt in the hardware
/// simulation).
///
/// NOTE: this means that incorrectly synchronized code may work fine on this
/// hardware simulation (even with randomized time slices), but it would not
/// work on real hardware.  (Just because we cannot always detect when your
/// program would fail in real life, does not mean it is ok to write
/// incorrectly synchronized code!)

```

**Interrupts:**

Interrupts are signals sent to the CPU by external devices, normally I/O devices. They tell the CPU to stop its current activities and execute the appropriate part of the operating system.

There are three types of interrupts:

- Hardware Interupts are generated by hardware devices to signal that they need some attention from the OS. They may have just received some data (e.g., keystrokes on the keyboard or an data on the ethernet card); or they have just completed a task which the operating system previous requested, such as transfering data between the hard drive and memory.
- Software Interupts are generated by programs when they want to request a system call to be performed by the operating system.
- Traps are generated by the CPU itself to indicate that some error or condition occured for which assistance from the operating system is needed.

Interrupts are important because they give the user better control over the computer. Without interrupts, a user may have to wait for a given application to have a higher priority over the CPU to be ran. This ensures that the CPU will deal with the process immediately.
