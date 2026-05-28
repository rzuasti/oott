CREATE INDEX idx_notifications_created_on ON notifications (created_on DESC);
CREATE INDEX idx_notifications_is_new_created_on ON notifications (is_new, created_on DESC);
