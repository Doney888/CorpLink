plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.10.0"
}
rootProject.name = "CorpLink"

include("common")
include("identity-service")
include("chat-service")