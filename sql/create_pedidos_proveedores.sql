-- Script DDL para crear la tabla PedidosProveedores en Supabase
CREATE TABLE IF NOT EXISTS "public"."PedidosProveedores" (
    "id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    "created_at" timestamptz DEFAULT timezone('utc'::text, now()) NOT NULL,
    "fecha_pedido" date DEFAULT current_date NOT NULL,
    "proveedor_id" uuid REFERENCES public."Proveedores"(id) ON DELETE SET NULL,
    "nombre_proveedor" text NOT NULL,
    "total_pagar" double precision DEFAULT 0.0 NOT NULL,
    "plazo_pago" integer DEFAULT 0 NOT NULL, -- Días de crédito
    "url_factura" text, -- URL del archivo comprobante en bucket
    "metodo_pago" text,
    "meses_sin_intereses" integer DEFAULT 0 NOT NULL, -- MSI: 0, 3, 6, 9, 12, 18
    "deuda" double precision DEFAULT 0.0 NOT NULL, -- Deuda restante
    "completado" boolean DEFAULT false NOT NULL
);
