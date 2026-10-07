-- Modern ESX owned_vehicles layout used by Lunar Garage.
-- Only run the CREATE if your table is missing type/job/stored.
-- The ALTER lines are safe to attempt if the columns are absent.

CREATE TABLE IF NOT EXISTS `owned_vehicles` (
    `owner` VARCHAR(60) NOT NULL,
    `plate` varchar(12) NOT NULL,
    `vehicle` longtext,
    `type` VARCHAR(20) NOT NULL DEFAULT 'car',
    `job` VARCHAR(20) NULL DEFAULT NULL,
    `stored` TINYINT(1) NOT NULL DEFAULT '0',
    PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Uncomment if the table already exists without these columns:
-- ALTER TABLE `owned_vehicles` ADD COLUMN `type` VARCHAR(20) NOT NULL DEFAULT 'car';
-- ALTER TABLE `owned_vehicles` ADD COLUMN `job` VARCHAR(20) NULL DEFAULT NULL;
-- ALTER TABLE `owned_vehicles` ADD COLUMN `stored` TINYINT(1) NOT NULL DEFAULT '0';
-- UPDATE `owned_vehicles` SET `stored` = 1 WHERE `job` IS NULL;
