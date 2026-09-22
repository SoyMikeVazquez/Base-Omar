-- =====================================================================
-- 1. MIGRACIÓN DE LA TABLA "Participantes"
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
-- 2. MIGRACIÓN DE LA TABLA "FinanzasPersonal"
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
-- 3. MIGRACIÓN DE LA TABLA "Citas"
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
