package ru.corplink.common.dto

data class RegisterUserRequest(
    val name: String,
    val email: String,
    val password: String
)