-- =====================================================================
-- ТЕСТИРОВАНИЕ И ВЕРИФИКАЦИИ СУБД CORPLINK
-- =====================================================================

-- 1. ТЕСТ ПРЕДСТАВЛЕНИЙ
SELECT * FROM v_chat_members_details;
SELECT * FROM v_unread_messages_count;

-- 2. ТЕСТ ПРОЦЕДУР
DO $$
DECLARE
    v_chat UUID := (SELECT id FROM chats LIMIT 1);
    v_msgs INT;
    v_members INT;
BEGIN
    CALL sp_get_chat_statistics(v_chat, v_msgs, v_members);
    RAISE NOTICE 'Статистика чата. Сообщений: %, Участников: %', v_msgs, v_members;
END $$;

-- 3. ТЕСТ ТРИГГЕРА ВАЛИДАЦИИ (Блокировка отправки не-участником)
INSERT INTO messages (chat_id, sender_id, content) 
VALUES (
    (SELECT id FROM chats LIMIT 1), 
    gen_random_uuid(), -- Фейковый UUID
    'Тестовый спам'
);

-- 4. ТЕСТ ИНДЕКСОВ И ПЛАНИРОВЩИКА (EXPLAIN)
SET enable_seqscan = off;

EXPLAIN ANALYZE
SELECT * FROM messages 
WHERE chat_id = (SELECT id FROM chats LIMIT 1)
ORDER BY sent_at DESC;
