-- Ejecutar en la base de datos de Grupo CG desde phpMyAdmin.
-- No modifica clientes existentes. Los datos no suministrados quedan vacíos.
SET NAMES utf8mb4;

INSERT INTO records (entity, payload)
SELECT 'clients', JSON_OBJECT(
    'name', nuevos.nombre,
    'document', '',
    'phone', '',
    'email', '',
    'address', ''
)
FROM (
    SELECT 'Jorge Navarro' AS nombre
    UNION ALL SELECT 'Carlos Zarabia'
    UNION ALL SELECT 'Farmaceutica Roma'
    UNION ALL SELECT 'Población Multidrogas'
    UNION ALL SELECT 'Barranquilla Multidrogas'
    UNION ALL SELECT 'Cartagena Multidrogas'
    UNION ALL SELECT 'Viajes Largos'
    UNION ALL SELECT 'Adicionales'
    UNION ALL SELECT 'Madecentro'
    UNION ALL SELECT 'Frutos del Bosque (Palenque)'
    UNION ALL SELECT 'Solia'
    UNION ALL SELECT 'Link Tigo'
    UNION ALL SELECT 'SERVICIOS LOGÍSTICOS DE COL'
) AS nuevos
WHERE NOT EXISTS (
    SELECT 1
    FROM records AS existentes
    WHERE existentes.entity = 'clients'
      AND LOWER(TRIM(JSON_UNQUOTE(JSON_EXTRACT(existentes.payload, '$.name'))))
          COLLATE utf8mb4_unicode_ci = LOWER(nuevos.nombre) COLLATE utf8mb4_unicode_ci
);

SELECT id, JSON_UNQUOTE(JSON_EXTRACT(payload, '$.name')) AS cliente
FROM records
WHERE entity = 'clients'
ORDER BY cliente;
