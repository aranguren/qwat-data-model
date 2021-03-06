/*
	qWat - QGIS Water Module

	SQL file :: valve table
*/

/* create */
CREATE TABLE qwat_od.valve ();
COMMENT ON TABLE qwat_od.valve IS 'Table for valve. Inherits from node.';

/* columns */
ALTER TABLE qwat_od.valve ADD COLUMN id integer NOT NULL REFERENCES qwat_od.network_element(id) PRIMARY KEY;
ALTER TABLE qwat_od.valve ADD COLUMN fk_valve_type     		 integer not null;
ALTER TABLE qwat_od.valve ADD COLUMN fk_valve_function       integer not null;
ALTER TABLE qwat_od.valve ADD COLUMN fk_valve_actuation      		 integer not null;
ALTER TABLE qwat_od.valve ADD COLUMN fk_pipe                 integer ;
ALTER TABLE qwat_od.valve ADD COLUMN fk_handle_precision     integer;
ALTER TABLE qwat_od.valve ADD COLUMN fk_handle_precisionalti integer;
ALTER TABLE qwat_od.valve ADD COLUMN fk_maintenance    		 integer[]; --TODO should use n:m relations!
ALTER TABLE qwat_od.valve ADD COLUMN diameter_nominal 		 varchar(10);
ALTER TABLE qwat_od.valve ADD COLUMN closed            		 boolean default false;
ALTER TABLE qwat_od.valve ADD COLUMN networkseparation 		 boolean default false;
ALTER TABLE qwat_od.valve ADD COLUMN handle_altitude         decimal(10,3);
ALTER TABLE qwat_od.valve ADD COLUMN handle_geometry         geometry(PointZ,:SRID);


/* constraints */
ALTER TABLE qwat_od.valve ADD CONSTRAINT valve_fk_type      FOREIGN KEY (fk_valve_type)     REFERENCES qwat_vl.valve_type(id)      MATCH FULL; CREATE INDEX fki_valve_fk_type      ON qwat_od.valve(fk_valve_type);
ALTER TABLE qwat_od.valve ADD CONSTRAINT valve_fk_function  FOREIGN KEY (fk_valve_function) REFERENCES qwat_vl.valve_function(id)  MATCH FULL; CREATE INDEX fki_valve_fk_function  ON qwat_od.valve(fk_valve_function);
ALTER TABLE qwat_od.valve ADD CONSTRAINT valve_fk_valve_actuation FOREIGN KEY (fk_valve_actuation)      REFERENCES qwat_vl.valve_actuation(id) MATCH FULL; CREATE INDEX fki_valve_fk_valve_actuation ON qwat_od.valve(fk_valve_actuation);
ALTER TABLE qwat_od.valve ADD CONSTRAINT valve_fk_pipe      FOREIGN KEY (fk_pipe)           REFERENCES qwat_od.pipe(id)            MATCH FULL; CREATE INDEX fki_valve_fk_pipe      ON qwat_od.valve(fk_pipe);
ALTER TABLE qwat_od.valve ADD CONSTRAINT valve_fk_handle_precision     FOREIGN KEY (fk_handle_precision)     REFERENCES qwat_vl.precision(id)     MATCH FULL; CREATE INDEX fki_valve_fk_handle_precision     ON qwat_od.valve(fk_handle_precision);
ALTER TABLE qwat_od.valve ADD CONSTRAINT valve_fk_handle_precisionalti FOREIGN KEY (fk_handle_precisionalti) REFERENCES qwat_vl.precisionalti(id) MATCH FULL; CREATE INDEX fki_valve_fk_handle_precisionalti ON qwat_od.valve(fk_handle_precisionalti);

/* cannot create constraint on arrays yet
ALTER TABLE qwat_od.valve ADD CONSTRAINT valve_fk_maintenance FOREIGN KEY (fk_maintenance) REFERENCES qwat_vl.valve_maintenance(id) MATCH FULL; CREATE INDEX fki_valve_fk_maintenance ON qwat_od.valve(fk_maintenance);
*/


/* NODE TRIGGER */
CREATE OR REPLACE FUNCTION qwat_od.ft_valve_node_set_type() RETURNS TRIGGER AS
$BODY$
	BEGIN
		PERFORM qwat_od.fn_node_set_type(NEW.id);
	RETURN NEW;
	END;
$BODY$
LANGUAGE plpgsql;
COMMENT ON FUNCTION qwat_od.ft_valve_node_set_type() IS 'Trigger: set-type of node after inserting a valve (to get orientation).';

CREATE TRIGGER valve_node_set_type
	AFTER INSERT ON qwat_od.valve
	FOR EACH ROW
	EXECUTE PROCEDURE qwat_od.ft_valve_node_set_type();
COMMENT ON TRIGGER valve_node_set_type ON qwat_od.valve IS 'Trigger: set-type of node after inserting a valve (to get orientation).';



/* HANDLE ALTITUDE TRIGGER */
CREATE OR REPLACE FUNCTION qwat_od.ft_valve_handle_altitude() RETURNS TRIGGER AS
$BODY$
	DECLARE
	BEGIN
		-- altitude is prioritary on Z value of the geometry (if both changed, only altitude is taken into account)
		IF NEW.handle_altitude IS NULL THEN
			NEW.handle_altitude := NULLIF( ST_Z(NEW.handle_geometry), 0.0); -- 0 is the NULL value
		END IF;
		IF 	NEW.handle_altitude IS NULL     AND ST_Z(NEW.handle_geometry) <> 0.0 OR
			NEW.handle_altitude IS NOT NULL AND ( ST_Z(NEW.handle_geometry) IS NULL OR ST_Z(NEW.handle_geometry) <> NEW.handle_altitude ) THEN
				NEW.handle_geometry := ST_SetSRID( ST_MakePoint( ST_X(NEW.handle_geometry), ST_Y(NEW.handle_geometry), COALESCE(NEW.handle_altitude,0) ), ST_SRID(NEW.handle_geometry) );
		END IF;
		RETURN NEW;
	END;
$BODY$
LANGUAGE plpgsql;
COMMENT ON FUNCTION qwat_od.ft_valve_handle_altitude() IS 'Trigger: when updating, check if altitude or Z value of geometry changed and synchronize them.';

CREATE TRIGGER valve_handle_altitude_update_trigger
	BEFORE UPDATE OF handle_altitude, handle_geometry ON qwat_od.valve
	FOR EACH ROW
	WHEN (NEW.handle_altitude <> OLD.handle_altitude OR ST_Z(NEW.handle_geometry) <> ST_Z(OLD.handle_geometry))
	EXECUTE PROCEDURE qwat_od.ft_valve_handle_altitude();
COMMENT ON TRIGGER valve_handle_altitude_update_trigger ON qwat_od.valve IS 'Trigger: when updating, check if altitude or Z value of geometry changed and synchronize them.';

CREATE TRIGGER valve_handle_altitude_insert_trigger
	BEFORE INSERT ON qwat_od.valve
	FOR EACH ROW
	EXECUTE PROCEDURE qwat_od.ft_valve_handle_altitude();
COMMENT ON TRIGGER valve_handle_altitude_insert_trigger ON qwat_od.valve IS 'Trigger: when updating, check if altitude or Z value of geometry changed and synchronize them.';
