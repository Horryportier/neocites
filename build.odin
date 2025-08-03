package neocites


import "core:bytes"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

OUTPUT_DIR :: "output/"
INPUT_DIR :: "input"

BLOG_POST_TEMPLATE_PATH :: "template/blog.html.temlpate"
INDEX_TEMPLATE_PATH :: "template/index.html.template"

INDEX_BLOG_POSTS_FMT_REPLACE_STR :: "$BLOG_POSTS$"

POST_CONTENT_FMT_REPLACE_STR :: "$POST_CONTENT$"
POST_HEADER_FMT_REPLACE_STR :: "$POST_HEADER$"

Result :: union($T: typeid, $E: typeid) {
	T,
	E,
}

PostPage :: struct {
	name:     string,
	raw_data: []byte,
	formated: []byte,
}

BlogPost :: struct {
	name:  string,
	posts: [dynamic]PostPage,
}

BlogPosts :: map[string]BlogPost

HtmlFormater :: proc(template, data: []byte) -> []byte


main :: proc() {
	blog_post_template, ok := os.read_entire_file_from_filename(BLOG_POST_TEMPLATE_PATH)
	if !ok {
		fmt.eprintln("can't open blog template")
	}
	blog_posts := load_posts(INPUT_DIR).(BlogPosts)
	for blog_post, data in blog_posts {
		for &post in data.posts {
			formated_content := format_html(fromat_blog_post, blog_post_template, post.raw_data)
			post.formated = format_blog_post_header(
				formated_content,
				create_blog_header(data.posts[:]),
			)
			fmt.println(string(post.formated))
		}
	}
	err := clear_outdir()
	fmt.println(err)
	err = save_blog_posts(blog_posts)
	fmt.println(err)
	index_template: []byte
	index_template, ok = os.read_entire_file_from_filename(INDEX_TEMPLATE_PATH)
	fromated := foramt_index_blog_post_links(index_template, create_index_postst_links(blog_posts))

	index: os.Handle
	if index, err = os.open("index.html", os.O_RDWR | os.O_CREATE, 0o666); err == nil {
		fmt.println(os.write(index, fromated))
	}
}

format_html :: proc(formater: HtmlFormater, template, data: []byte) -> []byte {
	return formater(template, data)
}

fromat_blog_post :: proc(template, data: []byte) -> []byte {
	lines := bytes.split(data, stob("\n"))
	formated_lines: [dynamic][]byte = fromat_markdown_to_html(lines)
	formated_input := bytes.join(formated_lines[:], stob("\n"))
	res, _ := bytes.replace(template, stob(POST_CONTENT_FMT_REPLACE_STR), formated_input, 1)
	return res
}

create_index_postst_links :: proc(blog_posts: BlogPosts) -> []byte {
	buf: [dynamic][]byte
	for blog_post, data in blog_posts {
		dir_path := strings.join({OUTPUT_DIR, blog_post}, "")
		html_extented := strings.join({strings.trim_right(data.posts[0].name, ".md"), ".html"}, "")
		post_path := strings.join({dir_path, html_extented}, "/")
		href_tag := strings.join({"href=\"", post_path, "\""}, "")
		append(&buf, apply_html_tag("a", stob(blog_post), href_tag))
	}
	return bytes.join(buf[:], stob("\n"))
}

create_blog_header :: proc(posts: []PostPage) -> []byte {
	buf: [dynamic][]byte
	for post, idx in posts {
		html_extented := strings.join({strings.trim_right(post.name, ".md"), ".html"}, "")
		idx_buff: [4]byte
		href_tag := strings.join({"href=\"", html_extented, "\""}, "")
		append(&buf, apply_html_tag("a", stob(strconv.itoa(idx_buff[:], idx)), href_tag))
	}
	return bytes.join(buf[:], stob(" "))
}

format_html_fn :: proc($T: string) -> HtmlFormater {
	fn := proc(template, data: []byte) -> []byte {
		res, _ := bytes.replace(template, stob(T), data, 1)
		return res
	}
	return fn
}

format_blog_post_header := format_html_fn(POST_HEADER_FMT_REPLACE_STR)

foramt_index_blog_post_links := format_html_fn(INDEX_BLOG_POSTS_FMT_REPLACE_STR)

fromat_markdown_to_html :: proc(lines: [][]byte) -> [dynamic][]byte {
	buf: [dynamic][]byte
	if_prefix := proc(
		line: []byte,
		buf: ^[dynamic][]byte,
		prefix, tag: string,
		strip_prefix: bool = true,
	) -> bool {
		if bytes.has_prefix(line, stob(prefix)) {
			_line: []byte
			if strip_prefix {
				_line, _ = bytes.remove(line, stob(prefix), 1)
			} else {
				_line = line
			}
			append(buf, apply_html_tag(tag, _line))
			return false
		}
		return true
	}
	for line in lines {
		if len(line) == 0 {
			append(&buf, stob("<br>"))
			continue
		}
		if bytes.has_prefix(line, stob("$IMAGE")) {
			words := bytes.split(line, stob(" "))
			if len(words) > 1 {
				append(&buf, bytes.join({stob("<img src=\""), words[1], stob("\">")}, stob("")))
			}
			continue
		}
		if_prefix(line, &buf, "# ", "h1") or_continue
		if_prefix(line, &buf, "## ", "h2") or_continue
		if_prefix(line, &buf, "### ", "h3") or_continue
		if_prefix(line, &buf, "#### ", "h4") or_continue
		if_prefix(line, &buf, "##### ", "h5") or_continue
		if_prefix(line, &buf, "###### ", "h6") or_continue

		append(&buf, apply_html_tag("p", line))
	}
	return buf
}


apply_html_tag :: proc(tag: string, data: []byte, options: string = "") -> []byte {
	tag_suffix := strings.join({"<", tag, " ", options, ">"}, "")
	tag_postfix := strings.join({"</", tag, ">"}, "")
	return bytes.join({stob(tag_suffix), data, stob(tag_postfix)}, stob(""))
}

stob :: proc(s: string) -> []byte {
	buff: [dynamic]byte
	for r in s {
		append(&buff, cast(byte)r)
	}
	return buff[:]
}

load_posts :: proc(dir: string) -> Result(BlogPosts, os.Error) {
	fd := os.open(dir) or_return
	file_info := os.read_dir(fd, 0) or_return
	blog_posts := make_map(BlogPosts)
	for info in file_info {
		if info.is_dir {
			switch x in load_post_pages(info.fullpath) {
			case [dynamic]PostPage:
				blog_posts[info.name] = {info.name, x}
			case os.Error:
				return x
			}
		}
	}
	return blog_posts
}

load_post_pages :: proc(dir: string) -> Result([dynamic]PostPage, os.Error) {
	fd := os.open(dir) or_return
	file_info := os.read_dir(fd, 0) or_return
	posts: [dynamic]PostPage
	for info in file_info {
		if !strings.ends_with(info.name, ".md") {
			continue
		}
		data := os.read_entire_file_from_filename(info.fullpath) or_continue
		append(&posts, PostPage{info.name, data, {}})
	}
	return posts
}

save_blog_posts :: proc(blog_posts: BlogPosts) -> os.Error {
	for blog_post, data in blog_posts {
		dir_path := strings.join({OUTPUT_DIR, blog_post}, "")
		if !os.exists(dir_path) {
			os.make_directory(dir_path) or_return
		}
		for post in data.posts {
			html_extented := strings.join({strings.trim_right(post.name, ".md"), ".html"}, "")
			post_path := strings.join({dir_path, html_extented}, "/")
			post_fd := os.open(post_path, os.O_RDWR | os.O_CREATE, 0o666) or_return
			os.write(post_fd, post.formated) or_return
			fmt.println("saved post at:", post_path)
		}
		fmt.println("saved blog at:", dir_path)
	}
	return nil
}

clear_outdir :: proc() -> os.Error {
	outdir := os.open(OUTPUT_DIR) or_return
	file_info := os.read_dir(outdir, 0) or_return
	for file in file_info {
		if file.is_dir {
			os.remove_directory(file.fullpath)
		}
	}
	return nil
}
