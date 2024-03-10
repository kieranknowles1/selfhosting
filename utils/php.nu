# PHP related utility functions

# Hash a password using PHP's password_hash function
# Assumes that the target container accepts PHPs PASSWORD_DEFAULT algorithm
export def "php hash_password" [
    password: string
] {
    docker run --rm php:8.2-cli php -r $"echo password_hash\('($password)', PASSWORD_DEFAULT\);"
}
