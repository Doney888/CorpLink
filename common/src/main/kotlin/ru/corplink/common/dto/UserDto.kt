package ru.corplink.common.dto

import java.util.UUID

data class UserDto(
    val id: UUID,
    val username: String,
    val email: String
)