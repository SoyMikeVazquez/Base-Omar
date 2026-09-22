-- =====================================================================
-- MASTER MIGRATION SCRIPT: TOTALPRO SCHEMA CLEANUP
-- Consolidates all table updates, ID removals, and primary key changes.
-- =====================================================================

-- =====================================================================
-- 1. TABLA: "users"
-- =====================================================================
-- Eliminar la restricción de clave primaria actual de la tabla 'users' (por defecto 'users_pkey')
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_pkey;

-- Eliminar la columna innecesaria 'id'
ALTER TABLE public.users DROP COLUMN IF EXISTS id;

-- Asignar 'IDUser' como la nueva clave primaria de la tabla
ALTER TABLE public.users ADD PRIMARY KEY ("IDUser");


-- =====================================================================
-- 2. TABLA: "Sucursales"
-- =====================================================================
-- Eliminar la restricción de clave primaria actual de la tabla 'Sucursales' (por defecto 'Sucursales_pkey')
ALTER TABLE public."Sucursales" DROP CONSTRAINT IF EXISTS "Sucursales_pkey";

-- Eliminar la columna innecesaria 'id' de la tabla 'Sucursales'
ALTER TABLE public."Sucursales" DROP COLUMN IF EXISTS id;

-- Asignar 'IDSucursal' como la nueva clave primaria de la tabla 'Sucursales'
ALTER TABLE public."Sucursales" ADD PRIMARY KEY ("IDSucursal");


-- =====================================================================
-- 3. TABLA: "Personal"
-- =====================================================================
-- Agregar la columna 'TipoPersonal' a la tabla 'Personal'
ALTER TABLE public."Personal" ADD COLUMN IF NOT EXISTS "TipoPersonal" text;


-- =====================================================================
-- =====================================================================
-- 4. TABLA: "Participantes"
-- =====================================================================
-- Eliminar la clave primaria y foránea actuales si existen
ALTER TABLE public."Participantes" DROP CONSTRAINT IF EXISTS "Participantes_userID_fkey";
ALTER TABLE public."Participantes" DROP CONSTRAINT IF EXISTS "Participantes_userID_pkey";
ALTER TABLE public."Participantes" DROP CONSTRAINT IF EXISTS "Participantes_pkey";

-- Eliminar la columna autogenerada 'id'
ALTER TABLE public."Participantes" DROP COLUMN IF EXISTS id;

-- Asegurar que la columna 'userID' sea de tipo uuid para que sea compatible con users("IDUser")
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='Participantes' AND column_name='userID') THEN
    ALTER TABLE public."Participantes" ALTER COLUMN "userID" TYPE uuid USING "userID"::uuid;
  ELSE
    ALTER TABLE public."Participantes" ADD COLUMN "userID" uuid;
  END IF;
END $$;

-- Establecer 'userID' como clave primaria y vincularla a la tabla 'users'
ALTER TABLE public."Participantes" ADD CONSTRAINT "Participantes_userID_pkey" PRIMARY KEY ("userID");
ALTER TABLE public."Participantes" ADD CONSTRAINT "Participantes_userID_fkey" 
  FOREIGN KEY ("userID") REFERENCES public.users("IDUser") ON DELETE CASCADE;


-- =====================================================================
-- 5. TABLA: "FinanzasPersonal"
-- =====================================================================
-- Eliminar la clave primaria actual
ALTER TABLE public."FinanzasPersonal" DROP CONSTRAINT IF EXISTS "FinanzasPersonal_pkey";

-- Eliminar la columna 'id'
ALTER TABLE public."FinanzasPersonal" DROP COLUMN IF EXISTS id;

-- Renombrar 'personal_id' a 'personalID' para consistencia con el estilo del proyecto
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='FinanzasPersonal' AND column_name='personal_id') THEN
    ALTER TABLE public."FinanzasPersonal" RENAME COLUMN personal_id TO "personalID";
  ELSE
    ALTER TABLE public."FinanzasPersonal" ADD COLUMN IF NOT EXISTS "personalID" text NOT NULL;
  END IF;
END $$;

-- Establecer fecha y personalID como no nulos
ALTER TABLE public."FinanzasPersonal" ALTER COLUMN "personalID" SET NOT NULL;
ALTER TABLE public."FinanzasPersonal" ALTER COLUMN "fecha" SET NOT NULL;

-- Asignar clave primaria compuesta (personalID, fecha)
ALTER TABLE public."FinanzasPersonal" ADD CONSTRAINT "FinanzasPersonal_pkey" PRIMARY KEY ("personalID", "fecha");

-- Re-crear el índice para la columna personalID
DROP INDEX IF EXISTS idx_finanzaspersonal_personal_id;
CREATE INDEX IF NOT EXISTS idx_finanzaspersonal_personal_id ON public."FinanzasPersonal" ("personalID");


-- =====================================================================
-- 6. TABLA: "Citas"
-- =====================================================================
-- Eliminar la clave primaria actual
ALTER TABLE public."Citas" DROP CONSTRAINT IF EXISTS "Citas_pkey";

-- Eliminar la columna 'id'
ALTER TABLE public."Citas" DROP COLUMN IF EXISTS id;

-- Asegurar que las columnas de la clave compuesta sean NOT NULL
ALTER TABLE public."Citas" ALTER COLUMN "clienteID" SET NOT NULL;
ALTER TABLE public."Citas" ALTER COLUMN "barberoID" SET NOT NULL;
ALTER TABLE public."Citas" ALTER COLUMN "servicioID" SET NOT NULL;
ALTER TABLE public."Citas" ALTER COLUMN "fecha" SET NOT NULL;
ALTER TABLE public."Citas" ALTER COLUMN "horaInicio" SET NOT NULL;

-- Establecer la clave primaria compuesta natural
ALTER TABLE public."Citas" ADD CONSTRAINT "Citas_pkey" 
  PRIMARY KEY ("clienteID", "barberoID", "servicioID", "fecha", "horaInicio");
