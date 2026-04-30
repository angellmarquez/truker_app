-- Activar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS postgis;

-- Tabla de Camiones
CREATE TABLE IF NOT EXISTS trucks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    license_plate TEXT UNIQUE NOT NULL,
    engine_serial TEXT,
    fuel_capacity FLOAT DEFAULT 0.0,
    current_fuel FLOAT DEFAULT 0.0,
    consumption_rate_l100km FLOAT DEFAULT 15.0, -- Default estimation
    last_latitude DOUBLE PRECISION,
    last_longitude DOUBLE PRECISION,
    status TEXT CHECK (status IN ('moving', 'stopped', 'maintenance')) DEFAULT 'stopped',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de Conductores (Extendiendo Auth Users)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    license_number TEXT,
    role TEXT CHECK (role IN ('admin', 'driver')) DEFAULT 'driver',
    qr_token TEXT UNIQUE,
    assigned_truck_id UUID REFERENCES trucks(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de Viajes y Carga
CREATE TABLE IF NOT EXISTS trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    truck_id UUID REFERENCES trucks(id),
    driver_id UUID REFERENCES profiles(id),
    cargo_details TEXT,
    start_time TIMESTAMPTZ DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    start_fuel FLOAT,
    end_fuel FLOAT,
    estimated_consumption FLOAT,
    distance_km FLOAT DEFAULT 0.0,
    is_active BOOLEAN DEFAULT TRUE
);

-- Tabla de Alertas
CREATE TABLE IF NOT EXISTS alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    truck_id UUID REFERENCES trucks(id),
    alert_type TEXT,
    location GEOGRAPHY(POINT),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla de Mantenimiento
CREATE TABLE IF NOT EXISTS maintenance_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    truck_id UUID REFERENCES trucks(id),
    service_date DATE NOT NULL,
    description TEXT,
    cost FLOAT,
    next_service_date DATE
);

-- Habilitar RLS (Row Level Security)
ALTER TABLE trucks ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;

-- Políticas de Seguridad (Ejemplo básico)
CREATE POLICY "Admins can do everything" ON trucks FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Drivers can view their assigned truck" ON trucks FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND assigned_truck_id = trucks.id)
);

-- Función para actualizar ubicación y detectar paradas (Lógica simplificada)
CREATE OR REPLACE FUNCTION update_truck_location(
    truck_id_param UUID,
    lat DOUBLE PRECISION,
    lon DOUBLE PRECISION,
    is_moving BOOLEAN
) RETURNS VOID AS $$
BEGIN
    UPDATE trucks 
    SET 
        last_latitude = lat,
        last_longitude = lon,
        status = CASE WHEN is_moving THEN 'moving' ELSE 'stopped' END,
        updated_at = NOW()
    WHERE id = truck_id_param;
    
    -- Si se detiene, podrías insertar una alerta aquí para que el backend dispare FCM
    IF NOT is_moving THEN
        INSERT INTO alerts (truck_id, alert_type, description)
        VALUES (truck_id_param, 'STOP_DETECTED', 'El camión se ha detenido.');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
