-- Script para complementar la tabla Proveedores con información adicional de compras/crédito
ALTER TABLE "public"."Proveedores" 
ADD COLUMN IF NOT EXISTS "categoria" text,
ADD COLUMN IF NOT EXISTS "metodos_pago" text,
ADD COLUMN IF NOT EXISTS "dias_credito" integer DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS "cantidad_habitual" integer DEFAULT 0 NOT NULL,
ADD COLUMN IF NOT EXISTS "precio_unitario" double precision DEFAULT 0.0 NOT NULL,
ADD COLUMN IF NOT EXISTS "precio_total_pedido" double precision DEFAULT 0.0 NOT NULL,
ADD COLUMN IF NOT EXISTS "lapso_pedido_dias" integer DEFAULT 0 NOT NULL;
