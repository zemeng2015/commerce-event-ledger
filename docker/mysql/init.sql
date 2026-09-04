-- Disposable local fixtures only. The official image creates the development
-- database and its app-user grant from compose.yaml before this file is run.
CREATE DATABASE IF NOT EXISTS `commerce_event_ledger_test`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- GRANT treats underscores as wildcards unless escaped, even in backticks.
GRANT ALL PRIVILEGES ON `commerce\_event\_ledger\_test`.*
  TO 'commerce_event_ledger'@'%';

-- There is no global grant and no access to unrelated databases. Tests currently
-- use one process and this fixed database; future worker databases need an
-- explicit fixture-only grant policy before enabling process parallelism.
