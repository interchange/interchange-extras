CREATE TABLE `ups_cache` (
      `code` int(11) NOT NULL AUTO_INCREMENT,
      `weight` varchar(12) DEFAULT NULL,
      `origin` varchar(12) DEFAULT NULL,
      `zip` varchar(12) DEFAULT NULL,
      `country` varchar(12) DEFAULT NULL,
      `shipmode` varchar(12) DEFAULT NULL,
      `cost` varchar(12) DEFAULT NULL,
      `updated` varchar(12) DEFAULT NULL,
      `is_res` varchar(12) DEFAULT NULL,
      PRIMARY KEY (`code`),
      KEY `ups_cache_code` (`code`),
      KEY `ups_cache_weight` (`weight`),
      KEY `ups_cache_origin` (`origin`),
      KEY `ups_cache_zip` (`zip`),
      KEY `ups_cache_shipmode` (`shipmode`),
      KEY `ups_cache_country` (`country`)
)
