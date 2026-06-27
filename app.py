import streamlit as st
import psycopg2
import redis
import pandas as pd

DB_CONFIG = "dbname=corplink_db user=postgres password=postgres host=localhost port=5432"

try:
    redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)
    redis_client.ping()
    redis_connected = True
except Exception:
    redis_connected = False

def get_connection():
    return psycopg2.connect(DB_CONFIG)

st.set_page_config(page_title="CorpLink DB Admin Panel", layout="wide")
st.title("🛡️ CorpLink — Интерактивная панель мониторинга БД")

if redis_connected:
    st.sidebar.success("🟢 Redis NoSQL: Подключен")
else:
    st.sidebar.error("🔴 Redis NoSQL: Отключен")

tab1, tab2, tab3 = st.tabs([
    "Чат и Процедуры (ЛР 3 + ЛР 5)", 
    "Триггеры и Аналитика (ЛР 4 + ЛР 5)", 
    "Телеметрия NoSQL (Redis) (ЛР 6)"
])

# =====================================================================
# ВКЛАДКА 1: Создание чатов через ПРОЦЕДУРУ и отправка сообщений
# =====================================================================
with tab1:
    conn = get_connection()
    cur = conn.cursor()
    
    cur.execute("SELECT id, username FROM users WHERE is_deleted = false")
    users = cur.fetchall()
    
    cur.execute("SELECT id, title FROM chats")
    chats = cur.fetchall()
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Создание чата через ПРОЦЕДУРУ")
        chat_title = st.text_input("Название группового чата", value="Новый отдел разработки")
        selected_creator = st.selectbox("Создатель чата (Владелец)", users, format_func=lambda x: x[1], key="creator_sel")
        
        if st.button("Вызвать процедуру (CALL sp_create_group_chat)"):
            if chat_title.strip():
                try:
                    cur.execute("CALL sp_create_group_chat(%s, %s, 2::smallint)", (selected_creator[0], chat_title))
                    conn.commit()
                    st.success(f"Чат '{chat_title}' создан, пользователь назначен Owner.")
                    st.rerun()
                except Exception as e:
                    conn.rollback()
                    st.error(f"Ошибка выполнения процедуры: {e}")

    with col2:
        st.subheader("Отправка сообщения (INSERT)")
        selected_sender = st.selectbox("Отправитель сообщения", users, format_func=lambda x: x[1], key="sender_sel")
        selected_chat = st.selectbox("Выбрать чат для отправки", chats, format_func=lambda x: x[1], key="chat_sel")
        msg_text = st.text_area("Текст сообщения", value="Коллеги, у нас новое обсуждение.")
        
        if st.button("Отправить (INSERT INTO messages)"):
            if msg_text.strip():
                try:
                    cur.execute(
                        "INSERT INTO messages (chat_id, sender_id, content) VALUES (%s, %s, %s)",
                        (selected_chat[0], selected_sender[0], msg_text)
                    )
                    conn.commit()
                    st.success("Сообщение добавлено!")
                    st.rerun()
                except Exception as e:
                    conn.rollback()
                    st.error(f"Ошибка вставки: {e}")
                    
    cur.close()
    conn.close()

# =====================================================================
# ВКЛАДКА 2: Триггер аудита правок и Представления (Views)
# =====================================================================
with tab2:
    conn = get_connection()
    cur = conn.cursor()
    
    st.subheader("Изменение сообщения и проверка работы ТРИГГЕРА")
    
    cur.execute("SELECT id, content FROM messages WHERE is_deleted = false ORDER BY sent_at DESC LIMIT 5")
    recent_msgs = cur.fetchall()
    
    if recent_msgs:
        selected_msg = st.selectbox("Выберите сообщение для редактирования", recent_msgs, format_func=lambda x: x[1])
        new_text = st.text_input("Новый текст сообщения", value=selected_msg[1])
        
        if st.button("Сохранить правку (UPDATE messages)"):
            if new_text.strip() and new_text != selected_msg[1]:
                try:
                    cur.execute("UPDATE messages SET content = %s WHERE id = %s", (new_text, selected_msg[0]))
                    conn.commit()
                    st.success("Сообщение обновлено!")
                    st.rerun()
                except Exception as e:
                    conn.rollback()
                    st.error(f"Ошибка обновления: {e}")
    else:
        st.info("В базе пока нет отправленных сообщений.")
        
    col_v1, col_v2 = st.columns(2)
    
    with col_v1:
        st.markdown("###Таблица аудита message_audit_logs (Заполняется триггером СУБД)")
        cur.execute("SELECT message_id, old_content, changed_at FROM message_audit_logs ORDER BY changed_at DESC")
        logs = cur.fetchall()
        df_logs = pd.DataFrame(logs, columns=["ID Сообщения", "Старый текст", "Время изменения"])
        st.dataframe(df_logs, use_container_width=True)

    with col_v2:
        st.markdown("###Выборка из VIEW (Детали участников)")
        cur.execute("SELECT username, chat_title, role_in_chat, department_name FROM v_chat_members_details")
        view_data = cur.fetchall()
        df_view = pd.DataFrame(view_data, columns=["Имя", "Чат", "Роль", "Отдел"])
        st.dataframe(df_view, use_container_width=True)
        
    cur.close()
    conn.close()

# =====================================================================
# ВКЛАДКА 3: Работа со статусами в NoSQL (Redis)
# =====================================================================
with tab3:
    st.subheader("Мониторинг статусов сотрудников в NoSQL СУБД Redis (Key-Value)")
    
    if redis_connected:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("SELECT id, username FROM users")
        all_users = cur.fetchall()
        
        col_u1, col_u2 = st.columns(2)
        
        with col_u1:
            st.markdown("#### Текущее состояние сети")
            for u in all_users:
                status = redis_client.get(f"user:presence:{u[0]}")
                if status == "online":
                    ttl = redis_client.ttl(f"user:presence:{u[0]}")
                    st.write(f"🟢 **{u[1]}** — В сети (Redis TTL: {ttl} сек.)")
                else:
                    st.write(f"⚪ **{u[1]}** — Офлайн")
                    
        with col_u2:
            st.markdown("#### Изменение статуса сотрудника")
            u_to_change = st.selectbox("Выберите сотрудника", all_users, format_func=lambda x: x[1], key="redis_u")
            
            if st.button("Имитировать вход (SET user:presence EX 60)"):
                redis_client.set(f"user:presence:{u_to_change[0]}", "online", ex=60)
                st.success(f"Пользователь {u_to_change[1]} вошел в сеть на 60 секунд!")
                st.rerun()
                
        cur.close()
        conn.close()
    else:
        st.error("Подключение к Redis отсутствует. Запустите службу Redis-сервера.")
