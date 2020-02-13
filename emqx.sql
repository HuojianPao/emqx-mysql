
DROP TABLE IF EXISTS `emqx_acl`;

CREATE TABLE `emqx_acl` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `allow` int(1) DEFAULT NULL COMMENT '0: deny, 1: allow',
  `ipaddr` varchar(60) DEFAULT NULL COMMENT 'IpAddress',
  `username` varchar(100) DEFAULT NULL COMMENT 'Username',
  `clientid` varchar(100) DEFAULT NULL COMMENT 'ClientId',
  `access` int(2) NOT NULL COMMENT '1: subscribe, 2: publish, 3: pubsub',
  `topic` varchar(100) NOT NULL DEFAULT '' COMMENT 'Topic Filter',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

LOCK TABLES `emqx_acl` WRITE;

INSERT INTO `emqx_acl` (`id`, `allow`, `ipaddr`, `username`, `clientid`, `access`, `topic`)
VALUES
	(1,1,NULL,'$all',NULL,2,'#'),
	(2,0,NULL,'$all',NULL,1,'$SYS/#'),
	(3,0,NULL,'$all',NULL,1,'eq #'),
	(4,1,'127.0.0.1',NULL,NULL,2,'$SYS/#'),
	(5,1,'127.0.0.1',NULL,NULL,2,'#'),
	(6,1,NULL,'dashboard',NULL,1,'$SYS/#');

UNLOCK TABLES;


DROP TABLE IF EXISTS `emqx_device`;

CREATE TABLE `emqx_device` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `username` varchar(100) DEFAULT NULL,
  `password` varchar(100) DEFAULT NULL,
  `salt` varchar(35) DEFAULT NULL,
  `is_superuser` tinyint(1) DEFAULT 0,
  `created` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `emqx_devicename` (`username`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

