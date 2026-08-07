# The Predator Model

AI coding assistants are fast. Sometimes a little too fast.

Give one a bug or a feature request and it may charge into the codebase, fire into every file in sight, refactor three unrelated systems, and return with a massive diff claiming the mission was successful because the project still compiles.

The Predator Model takes a different approach.

The terminology comes from the 1987 movie *Predator*, because software development already has enough boring process names.

**Dutch** is the developer leading the operation. Dutch knows what needs to change, controls the scope, and decides when the team is ready to move.

**Dillon** is the AI coding assistant. Dillon can move quickly, inspect a lot of terrain, and do plenty of damage—but only when Dutch points him in the right direction.

**The jungle** is the codebase. It is dense, interconnected, and full of behavior that may not be visible from the first file you open. Somewhere inside are old assumptions, async callbacks, stale state, hidden dependencies, and code nobody wants to touch because it appears to be working.

And somewhere in that jungle is **the Predator**.

The Predator may be a bug, a race condition, a regression risk, an invalid assumption, or some subtle piece of behavior waiting to tear apart an otherwise simple change.

The goal is not to enter the jungle and start shooting.

First, Dutch and Dillon study the terrain and set the trap. Then they make the smallest possible move. Finally, they look for green blood to prove they hit the real problem—and not some innocent subsystem standing behind it.

The workflow has three parts:

1. **Set the Trap** — Understand how the Predator moves before changing anything.
2. **Trigger the Trap** — Execute the plan with a small, controlled implementation.
3. **Green Blood Test** — Prove the Predator was hit and search for collateral damage.

> If it bleeds, we can kill it.

But first, we need to stop Dillon from firing blindly into the trees.

---

# 1. Set the Trap

At the beginning of *Predator*, the team does not yet understand what it is fighting. They know something is wrong, but they do not know where it is, how it moves, or what it can do.

Software problems often begin the same way.

A feature request may sound simple until the code reveals hidden state restoration, asynchronous work, cache invalidation, threading assumptions, or UI behavior spread across several files. The obvious implementation may solve the visible symptom while creating two new problems somewhere else in the jungle.

So the first phase is reconnaissance.

Dutch sends Dillon into the codebase to trace the relevant paths, inspect ownership boundaries, understand the current behavior, and identify where the real danger lives. Dillon reports back with the files involved, the risky paths, and the smallest safe implementation plan.

Nothing is changed yet.

The purpose of the trap is not to produce more planning documents. It is to prevent the AI from committing to an implementation before it understands what it is touching.

A good trap should answer questions such as:

- Where does the current behavior begin?
- Which files and functions actually control it?
- What state is involved?
- Are there asynchronous or threading concerns?
- What existing behavior must remain unchanged?
- What is the smallest safe path through the jungle?

The trap is ready when Dutch can look at the plan and say:

> Now we know where the damn thing is.

---

# 2. Trigger the Trap

Once the Predator's movement is understood, it is time to act.

This is where many AI coding sessions fall apart.

The assistant has a plan, but while implementing it, it discovers an old naming issue, an awkward abstraction, a duplicated helper, and a subsystem that could theoretically be rewritten more elegantly. Ten minutes later, the original bug fix has become an architectural renovation.

The Predator Model does not reward that kind of enthusiasm.

When Dutch triggers the trap, Dillon implements only the agreed-upon plan. The change should be narrow, deliberate, and easy to review. Existing behavior is preserved unless changing it is part of the mission. Unrelated cleanup stays in the jungle.

The goal is not to produce the cleverest implementation. The goal is to produce the smallest implementation that safely solves the actual problem.

That means:

- small diffs;
- isolated file changes;
- no opportunistic refactors;
- no speculative abstractions;
- no casual changes to threading or state ownership;
- no “while I'm here” nonsense.

Dillon should be able to explain what changed, why it was necessary, and why the surrounding jungle was left alone.

This phase is complete when the trap has fired and the implementation is in place.

But nobody starts celebrating yet.

The Predator may be wounded.

Or Dillon may have shot a tree.

---

# 3. Green Blood Test

In *Predator*, the green blood changes everything.

Until that moment, the creature is nearly invisible. Once it bleeds, Dutch knows it can be found, understood, and killed.

The Green Blood Test serves the same purpose in the workflow.

A build passing is useful, but it is not proof that the Predator was hit. Code can compile while still containing stale callbacks, invalid state restoration, broken mutation ordering, duplicate async work, cache invalidation problems, race conditions, and subtle changes to user interaction.

So after the implementation, Dillon goes back into the jungle.

This time the job is not to write more code. The job is to inspect the paths that changed and look for evidence.

- Did the fix actually address the original problem?
- Does state remain consistent?
- Can an old async completion overwrite newer data?
- Could the change trigger duplicate work?
- Was cache state invalidated correctly?
- Did the implementation preserve the existing interaction model?
- Did the bullet pass through the Predator and hit something behind it?

A successful build is evidence, but it is not the whole test. The Green Blood Test also calls for source-level verification, async tracing, state-consistency checks, race-condition analysis, duplicate-path checks, and actor or threading review.

Sometimes the test finds a confirmed issue, and the implementation needs another small correction.

Sometimes it finds nothing.

Both results are useful, as long as the review was real.

The Green Blood Test is complete when Dutch and Dillon have evidence that the intended problem was hit, the surrounding behavior remains intact, and no obvious danger is still moving through the trees.

