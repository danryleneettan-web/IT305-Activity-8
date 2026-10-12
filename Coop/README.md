# CoopConnect: Cooperative Member Portal

PHP/MySQL project for IT 305 Hands-on Activity 5, Set A.

## Setup

1. Start Apache and MySQL in XAMPP.
2. Copy this `cooperative-member-portal` folder to `C:\xampp\htdocs\`.
3. Open phpMyAdmin, then import `database.sql`.
4. Confirm database credentials in `config.php` (XAMPP normally uses `root` with a blank password).
5. Open `http://localhost/cooperative-member-portal/`.

## Demo accounts

- Staff: `admin` / `password`
- Member: `2026-0001` / `2026-0001` (the member will be prompted to change the default password).

The `admin` / `password` pair is a classroom demo credential. Change it before deploying the system outside a school demonstration.

## Included functionality

- Separate staff and member authentication
- Required-field validation, password-change workflow, and photo upload
- Member profile updates for personal, contact, spouse, children, parents, and references
- Staff dashboard, member creation, search, edit, delete, password reset, and print view
- MySQL tables with a foreign-key child-record relationship

## Suggested screenshots for submission

Capture the login page, staff dashboard, member profile update page, and the green successful-update confirmation after saving a profile.
