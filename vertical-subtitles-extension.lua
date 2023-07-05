function descriptor()
    return {
        title = "Vertical Subtitles Extension",
        version = "1.0.0",
        author = "dinglufe",
        url = "https://github.com/dinglufe/vertical-subtitles-extension",
        description = "Subtitle extension for VLC video player that allows controlling the video playback position by clicking on the subtitles.",
        capabilities = {"playing-listener", "input-listener"}
    }
end

function load_lyrics()
    local file_path = vlc.input.item():uri()
    if file_path == nil then
        return
    end

    -- load lyrics from *.srt
    local lyrics_file = string.gsub(file_path, "%.[^%.]*$", ".srt")
    lyrics_file = string.gsub(lyrics_file, "^file:///", "")
    -- vlc.msg.dbg("[VSET] Lyrics File: " .. lyrics_file)

    -- or load lyrics from *.wav.srt
    local lyrics_file2 = string.gsub(file_path, "%.[^%.]*$", ".wav.srt")
    lyrics_file2 = string.gsub(lyrics_file2, "^file:///", "")
    -- vlc.msg.dbg("[VSET] Lyrics File2: " .. lyrics_file2)

    local f = io.open(lyrics_file, "r")
    if f == nil then
        f = io.open(lyrics_file2, "r")
        if f == nil then
            vlc.msg.dbg("[VSET] Lyrics File Not Found " .. lyrics_file .. " or " .. lyrics_file2)
            return
        end
    end

    local line_index = 0
    local sentence_index = 1

    local start_time = 0
    local end_time = 0
    local lines = {}

    local w = vlc.dialog("VLC Vertical Subtitle")
    local ts = w:add_list(1, 1, 1, 1)

    for line in f:lines() do

        if line_index % 4 == 1 then
            local start_time_str, end_time_str = string.match(line, "(%d+:%d+:%d+,%d+) %-%-> (%d+:%d+:%d+,%d+)")
            local t1, t2, t3, t4 = string.match(start_time_str, "(%d+):(%d+):(%d+),(%d+)")
            start_time = t1 * 3600 + t2 * 60 + t3 + t4 * 0.001
            local e1, e2, e3, e4 = string.match(end_time_str, "(%d+):(%d+):(%d+),(%d+)")
            end_time = e1 * 3600 + e2 * 60 + e3 + e4 * 0.001
        elseif line_index % 4 == 2 then
            sentence_index = sentence_index + 1
            lines[sentence_index] = {line, start_time, end_time}

            local t = start_time
            local start_time = string.format("%02d:%02d:%02d", math.floor(t / 3600), math.floor(t / 60) % 60,
                math.floor(t) % 60)
            ts:add_value("[" .. start_time .. "] " .. line, sentence_index)
        end

        line_index = line_index + 1
    end

    f:close()

    function click()
        local s = ts:get_selection()
        local range = {}
        for i, text in pairs(s) do
            local v = lines[i]
            if range[1] == nil then
                range[1] = v[2]
                range[2] = v[3]
            else
                if v[2] < range[1] then
                    range[1] = v[2]
                end
                if v[3] > range[2] then
                    range[2] = v[3]
                end
            end
        end

        if range[1] ~= nil then
            -- vlc.msg.dbg("[VSET] Time: " .. range[1] .. " -> " .. range[2])
            vlc.var.set(vlc.object.input(), "time", range[1])
            vlc.var.set(vlc.object.input(), "start-time", range[1])
            vlc.var.set(vlc.object.input(), "stop-time", range[2])
        end
    end

    w:add_button("Switch to this sentence", click, 1, 2, 1, 1)
    w:show()
end

function key_press(var, old, key, data)
    -- vlc.msg.dbg("[VSET] key_press: " .. key)
    if key == 44 then
        -- vlc.msg.dbg("[VSET] key_press: ,")
        local start_time = vlc.var.get(vlc.object.input(), "start-time")
        vlc.var.set(vlc.object.input(), "time", start_time)
    end

    if key == 47 then
        -- vlc.msg.dbg("[VSET] key_press: /")
        local start_time = vlc.var.get(vlc.object.input(), "start-time")
        local stop_time = vlc.var.get(vlc.object.input(), "stop-time")

        if stop_time > start_time then
            local time = vlc.var.get(vlc.object.input(), "time")
            -- vlc.msg.dbg("[VSET] time: " .. time)
            -- vlc.msg.dbg("[VSET] start_time: " .. start_time)
            -- vlc.msg.dbg("[VSET] stop_time: " .. stop_time)

            if time < start_time - 0.5 or time > stop_time + 0.5 then
                vlc.var.set(vlc.object.input(), "time", start_time)
            end
        end
    end
end

function activate()
    load_lyrics()
    vlc.var.add_callback(vlc.object.libvlc(), "key-pressed", key_press)
end

function deactivate()
    vlc.var.del_callback(vlc.object.libvlc(), "key-pressed", key_press)
end

function meta_changed()
    load_lyrics()
end

function playing_changed()
end

function input_changed()
end

function close()
    vlc.deactivate()
end
