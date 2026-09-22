-- Add cliente_correo column to notas_venta table
ALTER TABLE public.notas_venta
ADD COLUMN IF NOT EXISTS cliente_correo TEXT;
