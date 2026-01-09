-- Adicionar colunas para suporte a mensagens de áudio
-- Execute este SQL no seu banco de dados para adicionar suporte a áudio

ALTER TABLE `zp_conversation_messages` 
ADD COLUMN `audio_duration` INT DEFAULT NULL COMMENT 'Duração do áudio em segundos',
ADD COLUMN `is_audio` TINYINT(1) DEFAULT 0 COMMENT 'Indica se a mensagem é de áudio (1) ou não (0)';

-- Criar índice para melhor performance nas consultas de áudio
CREATE INDEX `idx_is_audio` ON `zp_conversation_messages` (`is_audio`);

-- Comentário sobre as mudanças
-- audio_duration: armazena a duração do áudio em segundos
-- is_audio: flag booleana para identificar mensagens de áudio
-- Mensagens de áudio terão content vazio e media com a URL do arquivo de áudio