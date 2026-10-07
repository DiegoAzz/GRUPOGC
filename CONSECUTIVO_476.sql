-- Ejecutar UNA VEZ en la base de Grupo CG antes de generar la próxima cuenta.
-- Conserva los documentos existentes. MySQL no reutiliza IDs ocupados.
ALTER TABLE bills AUTO_INCREMENT = 476;

SHOW TABLE STATUS LIKE 'bills';
