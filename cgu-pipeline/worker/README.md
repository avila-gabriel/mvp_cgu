# worker

The worker performs the fetch work assigned by the master.

It claims an item URL, fetches the current page or archived page requested by
the work item, and reports the observed outcome back to the master.

Workers are stateless. Completed artifacts are persisted by the master.
