-- Create table for storing sales notes
CREATE TABLE IF NOT EXISTS public.notas_venta (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  folio SERIAL,
  cliente_nombre TEXT NOT NULL,
  cliente_direccion TEXT,
  cliente_telefono TEXT,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  descuento_especial NUMERIC DEFAULT 0,
  subtotal NUMERIC NOT NULL,
  total NUMERIC NOT NULL,
  finalizada BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS Configuration
ALTER TABLE public.notas_venta ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to read notas_venta" ON public.notas_venta
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to insert notas_venta" ON public.notas_venta
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to update notas_venta" ON public.notas_venta
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to delete notas_venta" ON public.notas_venta
  FOR DELETE USING (auth.role() = 'authenticated');
