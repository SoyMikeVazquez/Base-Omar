-- 1. Eliminar la restricción de clave primaria actual de la tabla 'users' (por defecto 'users_pkey')
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_pkey;

-- 2. Eliminar la columna innecesaria 'id'
ALTER TABLE public.users DROP COLUMN IF EXISTS id;

-- 3. Asignar 'IDUser' como la nueva clave primaria de la tabla
ALTER TABLE public.users ADD PRIMARY KEY ("IDUser");
