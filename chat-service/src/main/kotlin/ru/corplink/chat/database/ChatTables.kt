package ru.corplink.chat.database

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.javatime.datetime

object ChatTypesTable : Table("chat_types") {
    val id = short("id")
    val name = varchar("name", 30).uniqueIndex()
    override val primaryKey = PrimaryKey(id)
}

object RolesTable : Table("roles") {
    val id = short("id")
    val name = varchar("name", 30).uniqueIndex()
    override val primaryKey = PrimaryKey(id)
}

object ChatsTable : Table("chats") {
    val id = uuid("id").autoGenerate()
    // Внешний ключ на ChatTypesTable
    val typeId = short("type_id").references(ChatTypesTable.id)
    val title = varchar("title", 100).nullable()
    val createdAt = datetime("created_at")

    override val primaryKey = PrimaryKey(id)
}

object ChatMembersTable : Table("chat_members") {
    val id = uuid("id").autoGenerate()
    // Каскадное удаление указывается прямо в маппинге
    val chatId = uuid("chat_id").references(ChatsTable.id, onDelete = org.jetbrains.exposed.sql.ReferenceOption.CASCADE)
    // Мы ссылаемся на user_id как на UUID, но сама таблица users живет в другом микросервисе!
    // Это нормально для микросервисов: мы просто храним ссылку, а проверять ее будем по HTTP.
    val userId = uuid("user_id")
    val roleId = short("role_id").references(RolesTable.id)
    val joinedAt = datetime("joined_at")

    override val primaryKey = PrimaryKey(id)
}

object MessagesTable : Table("messages") {
    val id = uuid("id").autoGenerate()
    val chatId = uuid("chat_id").references(ChatsTable.id, onDelete = org.jetbrains.exposed.sql.ReferenceOption.CASCADE)
    val senderId = uuid("sender_id") // Ссылка на пользователя из другого сервиса
    val content = text("content")
    val isDeleted = bool("is_deleted").default(false)
    val sentAt = datetime("sent_at")
    val updatedAt = datetime("updated_at").nullable()

    override val primaryKey = PrimaryKey(id)
}