package ru.corplink.identity.database

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.javatime.datetime

object UsersTable : Table("users") {
    val id = uuid("id").autoGenerate()

    val departmentId = uuid("department_id")

    val username = varchar("username", 50).uniqueIndex()
    val email = varchar("email", 100).uniqueIndex()
    val passwordHash = text("password_hash")
    val isDeleted = bool("is_deleted").default(false)
    val createdAt = datetime("created_at")

    override val primaryKey = PrimaryKey(id)
}