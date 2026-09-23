# Human-reviewed documents

Make the document answer these questions, in this order when it helps the reader:

- What is wrong?
- Why does it happen? Explain the general mechanism before the instance, so the reader can recognise another occurrence.
- What changes?
- What stays unchanged?
- What evidence establishes this?

Open with **At a glance**: three sentences that state the problem and cause, the change, and what stays unchanged.

Quote exact evidence and label estimates. Put working cases beside failures.
Add a visual only when it answers one review question better than prose.
When the mechanism stays subtle, including in a spec `to-spec` just published, load `eli5` for the picture version and link its artifact at the foot.
When later evidence changes the analysis, update the body and attach that evidence to the comment.

The document is done when a reviewer can name the cause, change, and unchanged behavior from **At a glance** alone, without reconstructing the author's reasoning.
