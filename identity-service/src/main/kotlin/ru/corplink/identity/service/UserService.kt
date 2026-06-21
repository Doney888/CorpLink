package ru.corplink.identity.service

import org.jetbrains.exposed.sql.transactions.transaction
import org.jetbrains.exposed.sql.insert
import ru.corplink.common.dto.RegisterUserRequest
import ru.corplink.common.dto.UserDto
import ru.corplink.common.dto.LoginRequest
import ru.corplink.common.security.PasswordHasher
import ru.corplink.identity.database.UsersTable
import java.util.UUID
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.select

object UserService {
    fun register(request: RegisterUserRequest): UserDto? {
        return transaction {
            // Вставляем запись в таблицу PostgreSQL через Exposed DSL
            val insertedRow = UsersTable.insert {
                it[username] = request.name
                it[email] = request.email
                it[passwordHash] = PasswordHasher.hash(request.password)

                // В качестве дефолтного отдела привязываем IT-отдел из нашего SQL-дампа
                it[departmentId] = UUID.fromString("11111111-1111-1111-1111-111111111111")
            }

            // Возвращаем DTO-ответ созданного пользователя
            UserDto(
                id = insertedRow[UsersTable.id],
                username = insertedRow[UsersTable.username],
                email = insertedRow[UsersTable.email]
            )
        }
    }

    fun login(request: LoginRequest): UserDto? {
        return transaction {
            // Хэшируем введенный пароль для сравнения с БД
            val inputHash = PasswordHasher.hash(request.password)

            // Ищем строку, где совпадает и email, и хэш пароля
            val userRow = UsersTable.select {
                (UsersTable.email eq request.email) and (UsersTable.passwordHash eq inputHash)
            }.singleOrNull()

            // Если нашли — мапим в DTO и возвращаем, иначе — null
            if (userRow != null) {
                UserDto(
                    id = userRow[UsersTable.id],
                    username = userRow[UsersTable.username],
                    email = userRow[UsersTable.email]
                )
            } else {
                null
            }
        }
    }
}