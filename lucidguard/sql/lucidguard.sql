-- LucidGuard tables only (copy/paste safe)
-- Select database esxlegacy_39ab68 first, or keep the USE line below.

USE `esxlegacy_39ab68`;

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `lucidguard_bans` (
	`id` INT NOT NULL AUTO_INCREMENT,
	`license` VARCHAR(80) DEFAULT NULL,
	`license2` VARCHAR(80) DEFAULT NULL,
	`discord` VARCHAR(80) DEFAULT NULL,
	`steam` VARCHAR(80) DEFAULT NULL,
	`token` VARCHAR(128) DEFAULT NULL,
	`reason` VARCHAR(255) NOT NULL,
	`detection` VARCHAR(64) DEFAULT NULL,
	`banned_by` VARCHAR(64) NOT NULL DEFAULT 'LucidGuard',
	`created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	`expires_at` DATETIME DEFAULT NULL,
	`active` TINYINT NOT NULL DEFAULT 1,
	PRIMARY KEY (`id`),
	KEY `idx_license` (`license`),
	KEY `idx_token` (`token`),
	KEY `idx_active` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `lucidguard_vpn_cache` (
	`id` INT NOT NULL AUTO_INCREMENT,
	`ip_address` VARCHAR(45) NOT NULL,
	`is_vpn` TINYINT NOT NULL DEFAULT 0,
	`provider` VARCHAR(255) DEFAULT NULL,
	`country` VARCHAR(100) DEFAULT NULL,
	`cached_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	PRIMARY KEY (`id`),
	UNIQUE KEY `uq_ip` (`ip_address`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
