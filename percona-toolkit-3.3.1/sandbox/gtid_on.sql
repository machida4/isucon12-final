STOP SLAVE FOR CHANNEL '';
SET GLOBAL master_info_repository = 'TABLE';
SET @@GLOBAL.relay_log_info_repository = 'TABLE';
SET @@GLOBAL.ENFORCE_GTID_CONSISTENCY=ON;
SET @@GLOBAL.GTID_MODE = OFF_PERMISSIVE;
SET @@GLOBAL.GTID_MODE = ON_PERMISSIVE;
SET @@GLOBAL.GTID_MODE = ON;

