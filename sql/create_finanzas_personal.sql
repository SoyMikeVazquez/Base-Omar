-- SQL para crear la tabla FinanzasPersonal en Supabase

CREATE TABLE IF NOT EXISTS public."FinanzasPersonal" (
  "personalID" text NOT NULL,
  fecha timestamptz NOT NULL DEFAULT now(),
  servicios_ids text[] NOT NULL,
  servicios_detalle jsonb NOT NULL,
  suma_servicios numeric(10,2) NOT NULL DEFAULT 0,
  montos_extras numeric(10,2) NOT NULL DEFAULT 0,
  descripcion_extras text,
  total numeric(10,2) NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY ("personalID", "fecha")
);

-- Índices útiles
CREATE INDEX IF NOT EXISTS idx_finanzaspersonal_personal_id ON public."FinanzasPersonal" ("personalID");
