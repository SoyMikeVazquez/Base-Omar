-- Seed data for productos_mayoreo with volume discounts:
-- 30-59 pieces: 10% discount
-- 60+ pieces: 15% discount

INSERT INTO public.productos_mayoreo (nombre, precio_base, mini_descripcion, descuentos_por_volumen) VALUES
-- Ceras Base Agua 150g
('Cera Base Agua 150g (PET Transparente)', 55.00, 'Envase PET Transparente 150g', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),
('Cera Base Agua 150g (Aluminio Gris)', 62.00, 'Envase Aluminio Gris 150g', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),
('Cera Base Agua 150g (Aluminio Negro)', 62.00, 'Envase Aluminio Negro 150g', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),

-- Ceras Base Agua 250g
('Cera Base Agua 250g (PET Transparente)', 75.00, 'Envase PET Transparente 250g', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),

-- Ceras Mate 150g
('Cera Mate 150g (PET Transparente)', 58.00, 'Envase PET Transparente 150g', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),
('Cera Mate 150g (Aluminio Gris)', 65.00, 'Envase Aluminio Gris 150g', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),
('Cera Mate 150g (Aluminio Negro)', 65.00, 'Envase Aluminio Negro 150g', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),

-- Ceras Mate 250g
('Cera Mate 250g (PET Transparente)', 78.00, 'Envase PET Transparente 250g', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),

-- Minoxidil 5%
('Minoxidil 5% (30ml)', 75.00, 'Presentación 30ml', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),
('Minoxidil 5% (50ml)', 90.00, 'Presentación 50ml', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),

-- Polvo de Textura
('Polvo de Textura 40g (Envase Negro)', 60.00, 'Envase Negro 40g', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),
('Polvo de Textura 80g (Envase Negro)', 80.00, 'Envase Negro 80g', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),

-- After Shave
('After Shave 250ml', 52.00, 'Presentación 250ml', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb),
('After Shave 500ml', 72.00, 'Presentación 500ml', '[{"cantidad": 30, "porcentaje": 10}, {"cantidad": 60, "porcentaje": 15}]'::jsonb);
