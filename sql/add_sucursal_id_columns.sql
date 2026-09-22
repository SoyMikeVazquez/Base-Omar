-- =====================================================================
-- SQL MIGRATION: ADD sucursal_id COLUMN
-- Add sucursal_id column to Citas, FinanzasPersonal, and OrdenesProductos
-- and populate existing rows based on matching NombreSucursal.
-- =====================================================================

-- 1. Agregar columna sucursal_id a public."Citas"
ALTER TABLE public."Citas" ADD COLUMN IF NOT EXISTS sucursal_id text;

-- 2. Agregar columna sucursal_id a public."FinanzasPersonal"
ALTER TABLE public."FinanzasPersonal" ADD COLUMN IF NOT EXISTS sucursal_id text;

-- 3. Agregar columna sucursal_id a public."OrdenesProductos"
ALTER TABLE public."OrdenesProductos" ADD COLUMN IF NOT EXISTS sucursal_id text;

-- 4. Rellenar datos existentes basados en la tabla public."Sucursales"
-- Actualizar "Citas"
UPDATE public."Citas" c
SET sucursal_id = s."IDSucursal"
FROM public."Sucursales" s
WHERE TRIM(LOWER(c.sucursal)) = TRIM(LOWER(s."NombreSucursal"));

-- Actualizar "FinanzasPersonal"
UPDATE public."FinanzasPersonal" fp
SET sucursal_id = s."IDSucursal"
FROM public."Sucursales" s
WHERE TRIM(LOWER(fp.sucursal)) = TRIM(LOWER(s."NombreSucursal"));

-- Actualizar "OrdenesProductos"
UPDATE public."OrdenesProductos" op
SET sucursal_id = s."IDSucursal"
FROM public."Sucursales" s
WHERE TRIM(LOWER(op.sucursal)) = TRIM(LOWER(s."NombreSucursal"));
