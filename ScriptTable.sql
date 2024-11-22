/*
Cette DB est genere par l'intelligence artificielle seulement pour avoir une base de données et faire la démonstration 
des permissions des groupes sur la base de données
*/
-- Create the Authors table
CREATE TABLE Authors (
    AuthorID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL
);

-- Create the Publishers table
CREATE TABLE Publishers (
    PublisherID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL
);

-- Create the Books table
CREATE TABLE Books (
    BookID SERIAL PRIMARY KEY,
    Title VARCHAR(255) NOT NULL,
    AuthorID INT REFERENCES Authors(AuthorID),
    PublisherID INT REFERENCES Publishers(PublisherID)
);

-- Insert sample data into Authors table
INSERT INTO Authors (Name)
VALUES ('Author One'), ('Author Two'), ('Author Three');

-- Insert sample data into Publishers table
INSERT INTO Publishers (Name)
VALUES ('Publisher One'), ('Publisher Two');

-- Insert sample data into Books table
INSERT INTO Books (Title, AuthorID, PublisherID)
VALUES ('Book One', 1, 1),
       ('Book Two', 2, 2),
       ('Book Three', 3, 1);

       
CREATE TABLE users (
    username VARCHAR(50) PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    group_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL
);

