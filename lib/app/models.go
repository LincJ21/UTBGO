package main

// --- Modelos de Datos ---

type User struct {
	ID        int    `json:"id"`
	Username  string `json:"username"`
	Email     string `json:"email"`
	AvatarURL string `json:"avatarUrl"`
}

type Video struct {
	ID           string `json:"id"`
	Likes        int    `json:"likes"`
	IsLiked      bool   `json:"isLiked"`
	IsBookmarked bool   `json:"isBookmarked"`
}

type Comment struct {
	ID       string `json:"id"`
	UserID   string `json:"userId"`
	Username string `json:"username"`
	Text     string `json:"text"`
}
