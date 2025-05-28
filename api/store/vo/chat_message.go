package vo

type MsgContent struct {
	Text  string `json:"text"`
	Files []File `json:"files"`
}

type ChatMessage struct {
	Id         uint       `json:"id"`
	CreatedAt  int64      `json:"created_at"`
	UpdatedAt  int64      `json:"updated_at"`
	ChatId     string     `json:"chat_id"`
	UserId     uint       `json:"user_id"`
	RoleId     uint       `json:"role_id"`
	Model      string     `json:"model"`
	Type       string     `json:"type"`
	Icon       string     `json:"icon"`
	Tokens     int        `json:"tokens"`
	Content    MsgContent `json:"content"`
	UseContext bool       `json:"use_context"`
}
