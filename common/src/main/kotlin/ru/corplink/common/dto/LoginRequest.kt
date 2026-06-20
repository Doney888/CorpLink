package ru.corplink.common.dto

data class LoginRequest(
    val email: String,
    val password: String
)