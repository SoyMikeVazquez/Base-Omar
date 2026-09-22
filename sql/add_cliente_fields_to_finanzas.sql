-- Agregar columnas de relación con cliente a la tabla FinanzasPersonal
ALTER TABLE public."FinanzasPersonal" ADD COLUMN IF NOT EXISTS "cliente_id" text;
ALTER TABLE public."FinanzasPersonal" ADD COLUMN IF NOT EXISTS "cliente_email" text;
ALTER TABLE public."FinanzasPersonal" ADD COLUMN IF NOT EXISTS "cliente_telefono" text;
ALTER TABLE public."FinanzasPersonal" ADD COLUMN IF NOT EXISTS "cliente_nombre" text;

-- Agregar columnas de relación con cliente a la tabla OrdenesProductos
ALTER TABLE public."OrdenesProductos" ADD COLUMN IF NOT EXISTS "cliente_id" text;
ALTER TABLE public."OrdenesProductos" ADD COLUMN IF NOT EXISTS "cliente_email" text;
ALTER TABLE public."OrdenesProductos" ADD COLUMN IF NOT EXISTS "cliente_telefono" text;
ALTER TABLE public."OrdenesProductos" ADD COLUMN IF NOT EXISTS "cliente_nombre" text;
