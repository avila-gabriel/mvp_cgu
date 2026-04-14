update monitored_change
set
  status = $2
where
  id = $1;
