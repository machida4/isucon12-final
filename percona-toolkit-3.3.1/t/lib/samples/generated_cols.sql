CREATE TABLE `t1` (
  `ID` int(11) NOT NULL,
  `Column2` int(11) DEFAULT NULL,
  `Column3` int(11) GENERATED ALWAYS AS ((`Column2` + 1)) STORED,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
