package neocites


import "core:bytes"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

OUTPUT_DIR :: "output/"
INPUT_DIR :: "input"

BLOG_POST_TEMPLATE_PATH :: "template/blog.html.temlpate"

POST_FMT_REPLACE_STR :: "$POST_CONTENT$"

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
			post.formated = format_html(fromat_blog_post, blog_post_template, post.raw_data)
		}
	}
	err := save_blog_posts(blog_posts)
	fmt.println(err)
}

format_html :: proc(formater: HtmlFormater, template, data: []byte) -> []byte {
	return formater(template, data)
}

fromat_blog_post :: proc(template, data: []byte) -> []byte {
	lines := bytes.split(data, stob("\n"))
	formated_lines: [dynamic][]byte = fromat_markdown_to_html(lines)
	//for line, idx in lines {
	//	append(&formated_lines, bytes.join({stob("<p>"), line, stob("</p>")}, stob("")))
	//}
	formated_input := bytes.join(formated_lines[:], stob("\n"))
	res, _ := bytes.replace(template, stob(POST_FMT_REPLACE_STR), formated_input, 1)
	return res
}

fromat_markdown_to_html :: proc(lines: [][]byte) -> [dynamic][]byte {
	buf: [dynamic][]byte
	for line in lines {
		if len(line) == 0 {
			append(&buf, stob("<br>"))
			continue
		}
		if bytes.has_prefix(line, stob("#")) {
			append(&buf, apply_html_tag("h1", line))
			continue
		}
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
