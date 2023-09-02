-- CREATEと逆順
DROP TABLE IF EXISTS `user_gpas`;
DROP TABLE IF EXISTS `unread_announcements`;
DROP TABLE IF EXISTS `announcements`;
DROP TABLE IF EXISTS `submissions`;
DROP TABLE IF EXISTS `classes`;
DROP TABLE IF EXISTS `registrations`;
DROP TABLE IF EXISTS `courses`;
DROP TABLE IF EXISTS `users`;

-- master data
CREATE TABLE `users`
(
    `id`              CHAR(26) PRIMARY KEY,
    `code`            CHAR(6) UNIQUE              NOT NULL,
    `name`            VARCHAR(255)                NOT NULL,
    `hashed_password` BINARY(60)                  NOT NULL,
    `type`            ENUM ('student', 'teacher') NOT NULL
);

CREATE TABLE `courses`
(
    `id`          CHAR(26) PRIMARY KEY,
    `code`        VARCHAR(255) UNIQUE                                           NOT NULL,
    `type`        ENUM ('liberal-arts', 'major-subjects')                       NOT NULL,
    `name`        VARCHAR(255)                                                  NOT NULL,
    `description` TEXT                                                          NOT NULL,
    `credit`      TINYINT UNSIGNED                                              NOT NULL,
    `period`      TINYINT UNSIGNED                                              NOT NULL,
    `day_of_week` ENUM ('monday', 'tuesday', 'wednesday', 'thursday', 'friday') NOT NULL,
    `teacher_id`  CHAR(26)                                                      NOT NULL,
    `keywords`    TEXT                                                          NOT NULL,
    `status`      ENUM ('registration', 'in-progress', 'closed')                NOT NULL DEFAULT 'registration',
    CONSTRAINT FK_courses_teacher_id FOREIGN KEY (`teacher_id`) REFERENCES `users` (`id`)
);

CREATE TABLE `registrations`
(
    `course_id` CHAR(26),
    `user_id`   CHAR(26),
    PRIMARY KEY (`course_id`, `user_id`),
    CONSTRAINT FK_registrations_course_id FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`),
    CONSTRAINT FK_registrations_user_id FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
);

CREATE TABLE `classes`
(
    `id`                CHAR(26) PRIMARY KEY,
    `course_id`         CHAR(26)         NOT NULL,
    `part`              TINYINT UNSIGNED NOT NULL,
    `title`             VARCHAR(255)     NOT NULL,
    `description`       TEXT             NOT NULL,
    `submission_closed` TINYINT(1)       NOT NULL DEFAULT false,
    UNIQUE KEY `idx_classes_course_id_part` (`course_id`, `part`),
    CONSTRAINT FK_classes_course_id FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`)
);

CREATE TABLE `submissions`
(
    `user_id`   CHAR(26)     NOT NULL,
    `class_id`  CHAR(26)     NOT NULL,
    `file_name` VARCHAR(255) NOT NULL,
    `score`     TINYINT UNSIGNED,
    PRIMARY KEY (`user_id`, `class_id`),
    CONSTRAINT FK_submissions_user_id FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
    CONSTRAINT FK_submissions_class_id FOREIGN KEY (`class_id`) REFERENCES `classes` (`id`)
);

CREATE TABLE `announcements`
(
    `id`         CHAR(26) PRIMARY KEY,
    `course_id`  CHAR(26)     NOT NULL,
    `title`      VARCHAR(255) NOT NULL,
    `message`    TEXT         NOT NULL,
    CONSTRAINT FK_announcements_course_id FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`)
);

CREATE TABLE `unread_announcements`
(
    `announcement_id` CHAR(26)   NOT NULL,
    `user_id`         CHAR(26)   NOT NULL,
    `is_deleted`      TINYINT(1) NOT NULL DEFAULT false,
    PRIMARY KEY (`announcement_id`, `user_id`),
    CONSTRAINT FK_unread_announcements_announcement_id FOREIGN KEY (`announcement_id`) REFERENCES `announcements` (`id`),
    CONSTRAINT FK_unread_announcements_user_id FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
);

CREATE TABLE user_gpas (
    user_id char(26) PRIMARY KEY,
    gpa DECIMAL(10, 8)
);
CREATE TRIGGER after_course_update
    AFTER UPDATE ON courses
    FOR EACH ROW
BEGIN
    -- statusがclosedに変更された場合のみ処理を実行
    IF OLD.status <> 'closed' AND NEW.status = 'closed' THEN

        -- 今回更新されたコースを受講しているユーザについて、全てのclosedコースを考慮してGPAを再計算し、user_gpasテーブルにupsert
        INSERT INTO user_gpas (user_id, gpa)
        SELECT
            regs.user_id,
            IFNULL(SUM(subs.score * co.credit) / 100 / SUM(co.credit), 0) AS new_gpa
        FROM
            -- 更新されたコースに関連するユーザのリストを取得
            (SELECT DISTINCT user_id FROM registrations WHERE course_id = NEW.id) AS regs
        -- 上記のユーザが受講している全てのclosedステータスのコースをJOIN
        JOIN registrations ON regs.user_id = registrations.user_id
        JOIN courses co ON registrations.course_id = co.id AND co.status = 'closed'
        LEFT JOIN classes cl ON co.id = cl.course_id
        LEFT JOIN submissions subs ON regs.user_id = subs.user_id AND subs.class_id = cl.id
        GROUP BY
            regs.user_id
        ON DUPLICATE KEY UPDATE gpa = VALUES(gpa);

    END IF;
END;
