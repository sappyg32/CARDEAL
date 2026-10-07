KOJA CARDEALER -> LUNAR GARAGE (ESX) FIX
=======================================

WHAT WAS WRONG
--------------
server/main.lua called SaveVehicleToGarage(saveData), but shared/s_utils.lua was
never listed in fxmanifest.lua. The function was nil at runtime, so the vehicle
was never written to the database at all - while the purchase still reported
success. That is why the car looked "registered to you" but never appeared.

Even with the manifest fixed, the original insert only wrote
(identifier, plate, vehicle, state). Lunar Garage reads owned_vehicles with the
modern ESX column names:

    owner | plate | vehicle | type | job | stored

With no 'stored' column (or stored = 0) the garage treats the vehicle as
IMPOUNDED, not stored, so it never shows in the garage menu.

WHAT THIS PATCH DOES
--------------------
1. fxmanifest.lua      loads shared/s_utils.lua, so SaveVehicleToGarage and
                       Misc.Utils.SaveVehicle actually exist at runtime.
2. shared/s_utils.lua  inserts with the full modern ESX layout
                       (owner, plate, vehicle, type, job, stored = 1),
                       auto-detects INT vs VARCHAR(60) owner columns, and
                       falls back to older column sets if an insert fails.
                       QBCore keeps working (citizenid + mods + state).
3. shared/c_utils.lua  server-side Misc.Utils.SaveVehicle bridge plus a
                       'koja_cardealer:vehiclePurchased' event so another
                       garage resource can hook the purchase.
4. server/main.lua     passes the player source through and calls the bridge
                       right after the row insert.
5. server/leasing.lua  finance payments now update the framework owner column
                       ('owner' on ESX, 'citizenid' on QBCore) instead of a
                       hard-coded ESX column.

INSTALL
-------
1. Back up your current koja-cardealer folder.
2. Copy the files from fixed/koja-cardealer/ over your live resource, keeping
   the same paths.
3. Restart the resource: restart koja-cardealer   (or restart the server).

CHECK YOUR DATABASE SCHEMA
--------------------------
Run:

    DESCRIBE owned_vehicles;

It needs at least: owner, plate, vehicle, type, job, stored
If type, job or stored are missing, run schema.sql (included) or import the
table from Lunar Garage's install/ESX.md.

After a purchase this should return exactly one row with stored = 1:

    SELECT owner, plate, type, job, stored FROM owned_vehicles
    WHERE plate = 'YOURPLATE';

FIXING VEHICLES BOUGHT BEFORE THE PATCH
---------------------------------------
Cars bought before the patch are either missing from the table or sit at
stored = 0. Fix the ones that exist with:

    UPDATE owned_vehicles SET stored = 1, type = 'car' WHERE owner = 'YOUR_IDENTIFIER';

(Use the owner value you see in your own table - licence-style VARCHAR or INT.)
Reboot or restart lunar_garage afterwards if the list still looks stale.

NOTES
-----
* Lunar Garage is archived upstream; its ESX adapter is written for the modern
  owned_vehicles layout, which is what this patch writes.
* No Lunar Garage file needs to be edited on a standard ESX install.
* The 'contract' item (Lunar Garage dependency) is unrelated to this bug.
