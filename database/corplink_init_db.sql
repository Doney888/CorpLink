-- =====================================================================
-- Инициализация СУБД "CorpLink"
-- СУБД: PostgreSQL 13+
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Сброс старой структуры
DROP TABLE IF EXISTS message_audit_logs CASCADE;
DROP TABLE IF EXISTS message_reads CASCADE;
DROP TABLE IF EXISTS attachments CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS chat_members CASCADE;
DROP TABLE IF EXISTS chats CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS chat_types CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

-- ==========================================
-- 1. ТАБЛИЦЫ И ОГРАНИЧЕНИЯ (DDL)
-- ==========================================

CREATE TABLE departments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    CONSTRAINT uq_department_name UNIQUE (name),
    CONSTRAINT chk_dept_name_len CHECK (length(trim(name)) > 1)
);
COMMENT ON TABLE departments IS 'Справочник структурных подразделений компании';

CREATE TABLE chat_types (
    id SMALLINT PRIMARY KEY,
    name VARCHAR(30) NOT NULL,
    CONSTRAINT uq_chat_type_name UNIQUE (name)
);
COMMENT ON TABLE chat_types IS 'Типы чатов (Личный, Групповой, Канал)';

CREATE TABLE roles (
    id SMALLINT PRIMARY KEY,
    name VARCHAR(30) NOT NULL,
    CONSTRAINT uq_role_name UNIQUE (name)
);
COMMENT ON TABLE roles IS 'Роли прав доступа в чате';

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    department_id UUID NOT NULL,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    password_hash TEXT NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT fk_users_departments FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE RESTRICT,
    CONSTRAINT uq_users_username UNIQUE (username),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$')
);
COMMENT ON TABLE users IS 'Учетные записи сотрудников (с поддержкой Soft Delete)';

CREATE TABLE chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type_id SMALLINT NOT NULL,
    title VARCHAR(100), 
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT fk_chats_type FOREIGN KEY (type_id) REFERENCES chat_types(id) ON DELETE RESTRICT
);
COMMENT ON TABLE chats IS 'Реестр созданных чатов';

CREATE TABLE chat_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role_id SMALLINT NOT NULL,
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT fk_members_chats FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
    CONSTRAINT fk_members_users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_members_roles FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT,
    CONSTRAINT uq_chat_user UNIQUE (chat_id, user_id)
);
COMMENT ON TABLE chat_members IS 'Связь "многие-ко-многим" (состав участников чатов)';

CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    content TEXT NOT NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT false,
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_messages_chats FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
    CONSTRAINT fk_messages_users FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_content_not_empty CHECK (length(trim(content)) > 0)
);
COMMENT ON TABLE messages IS 'История отправленных текстовых сообщений';

CREATE TABLE attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL,
    file_url TEXT NOT NULL,
    file_type VARCHAR(50) NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    CONSTRAINT fk_attachments_messages FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    CONSTRAINT chk_file_size CHECK (file_size_bytes > 0 AND file_size_bytes <= 104857600)
);
COMMENT ON TABLE attachments IS 'Вложения (файлы, изображения)';

CREATE TABLE message_reads (
    message_id UUID NOT NULL,
    user_id UUID NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT pk_message_reads PRIMARY KEY (message_id, user_id),
    CONSTRAINT fk_reads_messages FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
    CONSTRAINT fk_reads_users FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
COMMENT ON TABLE message_reads IS 'Телеметрия прочтения сообщений';

CREATE TABLE message_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL,
    old_content TEXT NOT NULL,
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    CONSTRAINT fk_audit_messages FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);
COMMENT ON TABLE message_audit_logs IS 'Аудит: история правок (заполняется триггером)';

-- ==========================================
-- 2. ЗАПОЛНЕНИЕ ДАННЫМИ (DML / SEEDING)
-- ==========================================

INSERT INTO chat_types (id, name) VALUES (1, 'Private'), (2, 'Group'), (3, 'Channel');
INSERT INTO roles (id, name) VALUES (1, 'Owner'), (2, 'Admin'), (3, 'Member'), (4, 'ReadOnly');

INSERT INTO departments (id, name) VALUES 
('11111111-1111-1111-1111-111111111111', 'Департамент IT'),
('22222222-2222-2222-2222-222222222222', 'Служба ИБ'),
('33333333-3333-3333-3333-333333333333', 'Отдел продаж');

INSERT INTO users (department_id, username, email, password_hash) VALUES 
((SELECT id FROM departments WHERE name = 'Департамент IT'), 'dev_ivan', 'ivan@corplink.local', 'hashed_pass_1'),
((SELECT id FROM departments WHERE name = 'Департамент IT'), 'dev_anna', 'anna@corplink.local', 'hashed_pass_2'),
((SELECT id FROM departments WHERE name = 'Служба ИБ'), 'sec_boris', 'boris@corplink.local', 'hashed_pass_3');

INSERT INTO chats (type_id, title) VALUES (2, 'Планирование релиза');

INSERT INTO chat_members (chat_id, user_id, role_id) VALUES 
((SELECT id FROM chats WHERE title = 'Планирование релиза'), (SELECT id FROM users WHERE username = 'dev_ivan'), 2),
((SELECT id FROM chats WHERE title = 'Планирование релиза'), (SELECT id FROM users WHERE username = 'dev_anna'), 3);

INSERT INTO messages (chat_id, sender_id, content) VALUES 
((SELECT id FROM chats WHERE title = 'Планирование релиза'), (SELECT id FROM users WHERE username = 'dev_ivan'), 'Всем привет! Начинаем подготовку релиза.'),
((SELECT id FROM chats WHERE title = 'Планирование релиза'), (SELECT id FROM users WHERE username = 'dev_anna'), 'Привет. Ветку в Git обновила.');

INSERT INTO attachments (message_id, file_url, file_type, file_size_bytes) VALUES 
((SELECT id FROM messages WHERE content LIKE '%Ветку в Git%'), 's3://bucket/git_report.pdf', 'application/pdf', 1024500);

-- ==========================================
-- 3. ПРЕДСТАВЛЕНИЯ (VIEWS) И ИНДЕКСЫ
-- ==========================================

CREATE OR REPLACE VIEW v_chat_members_details AS
SELECT cm.chat_id, c.title AS chat_title, cm.user_id, u.username, d.name AS department_name, r.name AS role_in_chat
FROM chat_members cm
JOIN chats c ON cm.chat_id = c.id
JOIN users u ON cm.user_id = u.id
JOIN departments d ON u.department_id = d.id
JOIN roles r ON cm.role_id = r.id;

CREATE OR REPLACE VIEW v_unread_messages_count AS
SELECT m.chat_id, c.title AS chat_title, cm.user_id, u.username, COUNT(m.id) AS unread_count
FROM messages m
JOIN chats c ON m.chat_id = c.id
JOIN chat_members cm ON c.id = cm.chat_id
JOIN users u ON cm.user_id = u.id
WHERE m.sender_id != cm.user_id AND m.is_deleted = false
  AND NOT EXISTS (SELECT 1 FROM message_reads mr WHERE mr.message_id = m.id AND mr.user_id = cm.user_id)
GROUP BY m.chat_id, c.title, cm.user_id, u.username;

CREATE INDEX idx_messages_chat_sent_at ON messages (chat_id, sent_at DESC);
CREATE INDEX idx_chat_members_chat_user ON chat_members (chat_id, user_id);

-- ==========================================
-- 4. ХРАНИМЫЕ ПРОЦЕДУРЫ И ФУНКЦИИ (ЛР 5)
-- ==========================================

-- 4.1 Процедура: Транзакционное создание чата
CREATE OR REPLACE PROCEDURE sp_create_group_chat(p_creator_id UUID, p_chat_title VARCHAR(100), p_chat_type SMALLINT)
LANGUAGE plpgsql AS $$
DECLARE v_new_chat_id UUID;
BEGIN
    v_new_chat_id := gen_random_uuid();
    INSERT INTO chats (id, type_id, title) VALUES (v_new_chat_id, p_chat_type, p_chat_title);
    INSERT INTO chat_members (chat_id, user_id, role_id) VALUES (v_new_chat_id, p_creator_id, 1);
END; $$;

-- 4.2 Процедура: Статистика чата (IN/OUT параметры)
CREATE OR REPLACE PROCEDURE sp_get_chat_statistics(IN p_chat_id UUID, OUT out_msg_count INT, OUT out_members_count INT)
LANGUAGE plpgsql AS $$
BEGIN
    SELECT COUNT(*) INTO out_msg_count FROM messages WHERE chat_id = p_chat_id;
    SELECT COUNT(*) INTO out_members_count FROM chat_members WHERE chat_id = p_chat_id;
END; $$;

-- 4.3 Функция: Получение списка чатов пользователя (Возврат таблицы)
CREATE OR REPLACE FUNCTION fn_get_user_chats(p_user_id UUID)
RETURNS TABLE (chat_id UUID, chat_title VARCHAR, user_role VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.title, r.name::VARCHAR FROM chats c
    JOIN chat_members cm ON c.id = cm.chat_id JOIN roles r ON cm.role_id = r.id
    WHERE cm.user_id = p_user_id;
END; $$;

-- ==========================================
-- 5. ТРИГГЕРЫ (7 ШТУК ДЛЯ ЛР 5)
-- ==========================================

-- Триггер 1: Аудит правок и удалений сообщений 
CREATE OR REPLACE FUNCTION fn_audit_message_edits() RETURNS TRIGGER AS $$
BEGIN
    -- Если сообщение редактируют
    IF TG_OP = 'UPDATE' THEN
        IF NEW.content <> OLD.content THEN
            -- Сохраняем старый текст
            INSERT INTO message_audit_logs (message_id, old_content) VALUES (OLD.id, OLD.content);
            NEW.updated_at := now();
        END IF;
        RETURN NEW;
    -- Если сообщение удаляют
    ELSIF TG_OP = 'DELETE' THEN
        -- Сохраняем удаленный текст с пометкой
        INSERT INTO message_audit_logs (message_id, old_content) VALUES (OLD.id, '[УДАЛЕНО ФИЗИЧЕСКИ] ' || OLD.content);
        RETURN OLD;
    END IF;
    RETURN NULL;
END; $$ LANGUAGE plpgsql;
-- Привязываем триггер сразу на два события: UPDATE и DELETE
CREATE TRIGGER trg_audit_message_edits
BEFORE UPDATE OR DELETE ON messages
FOR EACH ROW EXECUTE FUNCTION fn_audit_message_edits();

-- Триггер 2: Защита "узкого места" (Отправка только участниками)
CREATE OR REPLACE FUNCTION fn_check_sender_in_chat() RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM chat_members WHERE chat_id = NEW.chat_id AND user_id = NEW.sender_id) THEN
        RAISE EXCEPTION 'Security Violation: Пользователь не состоит в данном чате и не может писать сообщения!';
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_check_sender_in_chat BEFORE INSERT ON messages FOR EACH ROW EXECUTE FUNCTION fn_check_sender_in_chat();

-- Триггер 3: Каскадный Soft Delete сообщений
CREATE OR REPLACE FUNCTION fn_cascade_soft_delete_user() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_deleted = true AND OLD.is_deleted = false THEN
        UPDATE messages SET is_deleted = true WHERE sender_id = NEW.id;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_cascade_soft_delete_user AFTER UPDATE OF is_deleted ON users FOR EACH ROW EXECUTE FUNCTION fn_cascade_soft_delete_user();

-- Триггер 4: Лимит участников приватного чата
CREATE OR REPLACE FUNCTION fn_limit_private_chat() RETURNS TRIGGER AS $$
DECLARE v_chat_type SMALLINT; v_member_count INT;
BEGIN
    SELECT type_id INTO v_chat_type FROM chats WHERE id = NEW.chat_id;
    IF v_chat_type = 1 THEN 
        SELECT COUNT(*) INTO v_member_count FROM chat_members WHERE chat_id = NEW.chat_id;
        IF v_member_count >= 2 THEN RAISE EXCEPTION 'Business Rule Violation: В приватном чате не может быть больше 2 участников!'; END IF;
    END IF;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_limit_private_chat BEFORE INSERT ON chat_members FOR EACH ROW EXECUTE FUNCTION fn_limit_private_chat();

-- Триггер 5: Защита Владельца
CREATE OR REPLACE FUNCTION fn_protect_owner_deletion() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.role_id = 1 THEN RAISE EXCEPTION 'Business Rule Violation: Нельзя удалить Владельца из чата!'; END IF;
    RETURN OLD;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_protect_owner_deletion BEFORE DELETE ON chat_members FOR EACH ROW EXECUTE FUNCTION fn_protect_owner_deletion();

-- Триггер 6: Авто-прочтение своих сообщений
CREATE OR REPLACE FUNCTION fn_auto_read_own_message() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO message_reads (message_id, user_id, read_at) VALUES (NEW.id, NEW.sender_id, now()) ON CONFLICT DO NOTHING;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_auto_read_own_message AFTER INSERT ON messages FOR EACH ROW EXECUTE FUNCTION fn_auto_read_own_message();

-- Триггер 7: Авто-удаление пустых чатов
CREATE OR REPLACE FUNCTION fn_delete_empty_chat() RETURNS TRIGGER AS $$
DECLARE v_member_count INT;
BEGIN
    SELECT COUNT(*) INTO v_member_count FROM chat_members WHERE chat_id = OLD.chat_id;
    IF v_member_count = 0 THEN DELETE FROM chats WHERE id = OLD.chat_id; END IF;
    RETURN OLD;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_delete_empty_chat AFTER DELETE ON chat_members FOR EACH ROW EXECUTE FUNCTION fn_delete_empty_chat();

-- ==========================================
-- 6. ДЕМОНСТРАЦИЯ CRUD (UPDATE, DELETE - ЛР 4)
-- ==========================================
UPDATE messages SET content = 'Привет! Текст обновлен.' WHERE content LIKE '%Всем привет!%';
DELETE FROM departments WHERE name = 'Отдел продаж';
