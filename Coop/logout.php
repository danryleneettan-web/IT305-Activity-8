<?php

require 'config.php';

session_unset();
session_destroy();
session_start();

flash('success', 'You have been signed out.');
redirect('index.php');