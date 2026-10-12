CREATE DATABASE IF NOT EXISTS cooperative_portal
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE cooperative_portal;

CREATE TABLE staff (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    full_name VARCHAR(120) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE members (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    account_number VARCHAR(30) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    force_password_change TINYINT(1) NOT NULL DEFAULT 1,
    last_name VARCHAR(80) NOT NULL,
    first_name VARCHAR(80) NOT NULL,
    middle_name VARCHAR(80) DEFAULT '',
    extension_name VARCHAR(20) DEFAULT '',
    civil_status VARCHAR(20) NOT NULL,
    address TEXT NOT NULL,
    contact_number VARCHAR(30) NOT NULL,
    birthday DATE NOT NULL,
    occupation VARCHAR(120) DEFAULT '',
    employer VARCHAR(120) DEFAULT '',
    employer_address VARCHAR(255) DEFAULT '',
    spouse_name VARCHAR(160) DEFAULT '',
    spouse_occupation VARCHAR(120) DEFAULT '',
    spouse_employer VARCHAR(120) DEFAULT '',
    father_name VARCHAR(160) DEFAULT '',
    mother_name VARCHAR(160) DEFAULT '',
    reference_one VARCHAR(160) DEFAULT '',
    reference_two VARCHAR(160) DEFAULT '',
    photo VARCHAR(100) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE children (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    member_id INT UNSIGNED NOT NULL,
    child_name VARCHAR(160) NOT NULL,
    age TINYINT UNSIGNED NOT NULL,
    CONSTRAINT fk_child_member FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE
);

INSERT INTO staff (username, full_name, password_hash)
VALUES (
    'admin',
    'Cooperative Administrator',
    '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.'
);

INSERT INTO members (
    account_number, password_hash, force_password_change, last_name, first_name,
    civil_status, address, contact_number, birthday, occupation
)
VALUES (
    '2026-0001',
    '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.',
    1,
    'Santos',
    'Maria',
    'Single',
    'Malolos, Bulacan',
    '09171234567',
    '2000-05-18',
    'Teacher'
);