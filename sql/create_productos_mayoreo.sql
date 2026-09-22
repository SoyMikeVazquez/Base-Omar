-- Create the productos_mayoreo table
CREATE TABLE IF NOT EXISTS public.productos_mayoreo (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  nombre TEXT NOT NULL,
  precio_base NUMERIC NOT NULL,
  mini_descripcion TEXT,
  descuentos_por_volumen JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS (Row Level Security)
ALTER TABLE public.productos_mayoreo ENABLE ROW LEVEL SECURITY;

-- Create policies for access control
-- Note: Replace with appropriate roles if needed, here we allow authenticated users to view and modify
CREATE POLICY "Allow authenticated users to read" ON public.productos_mayoreo
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to insert" ON public.productos_mayoreo
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to update" ON public.productos_mayoreo
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to delete" ON public.productos_mayoreo
  FOR DELETE USING (auth.role() = 'authenticated');
