-- 1. Eliminar la restricción de clave primaria actual de la tabla 'Sucursales' (por defecto 'Sucursales_pkey')
ALTER TABLE public."Sucursales" DROP CONSTRAINT IF EXISTS "Sucursales_pkey";

-- 2. Eliminar la columna innecesaria 'id' de la tabla 'Sucursales'
ALTER TABLE public."Sucursales" DROP COLUMN IF EXISTS id;

-- 3. Asignar 'IDSucursal' como la nueva clave primaria de la tabla 'Sucursales'
ALTER TABLE public."Sucursales" ADD PRIMARY KEY ("IDSucursal");

-- 4. Agregar la columna 'TipoPersonal' a la tabla 'Personal'
ALTER TABLE public."Personal" ADD COLUMN IF NOT EXISTS "TipoPersonal" text;
