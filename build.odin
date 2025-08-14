package neocites


import "core:bytes"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import cr "vendor:commonmark"

OUTPUT_DIR :: "output/"
INPUT_DIR :: "input"

BLOG_POST_TEMPLATE_PATH :: "template/blog.html.temlpate"
INDEX_TEMPLATE_PATH :: "template/index.html.template"

GALLERY_DIR_PATH :: "assets/gallery"
GALLERY_MIN_COLLUMS :: 2

INDEX_BLOG_POSTS_FMT_REPLACE_STR :: "$BLOG_POSTS$"
INDEX_GALERRY_FMT_REPLACE_STR :: "$GALLERY$"

POST_CONTENT_FMT_REPLACE_STR :: "$POST_CONTENT$"
POST_HEADER_FMT_REPLACE_STR :: "$POST_HEADER$"

Result :: union($T: typeid, $E: typeid) {
	T,
	E,
}

PostPage :: struct {
	name:     string,
	raw_data: []byte,
	formated: string,
}

BlogPost :: struct {
	name:  string,
	posts: [dynamic]PostPage,
}

BlogPosts :: map[string]BlogPost

HtmlFormater :: proc(template, data: string) -> string


format_blog_post_header := format_html_fn(POST_HEADER_FMT_REPLACE_STR)
foramt_index_blog_post_links := format_html_fn(INDEX_BLOG_POSTS_FMT_REPLACE_STR)
foramt_galerry_post_links := format_html_fn(INDEX_GALERRY_FMT_REPLACE_STR)

main :: proc() {
	blog_post_template, ok := os.read_entire_file_from_filename(BLOG_POST_TEMPLATE_PATH)
	if !ok {
		fmt.eprintln("can't open blog template")
	}
	blog_posts := load_posts(INPUT_DIR).(BlogPosts)
	for blog_post, data in blog_posts {
		for &post in data.posts {
			formated_content := format_html(
				fromat_blog_post,
				string(blog_post_template),
				string(post.raw_data),
			)
			post.formated = format_blog_post_header(
				formated_content,
				create_blog_header(data.posts[:]),
			)
		}
	}
	err := clear_outdir()
	if err != nil {
		fmt.println(err)
	}
	err = save_blog_posts(blog_posts)
	if err != nil {
		fmt.println(err)
	}
	index_template: []byte
	index_template, ok = os.read_entire_file_from_filename(INDEX_TEMPLATE_PATH)
	fromated_blogs := foramt_index_blog_post_links(
		string(index_template),
		create_index_postst_links(blog_posts),
	)
	galerry := create_galery_images()
	#partial switch v in galerry {
	case os.Error:
		fmt.eprintln("could not crate gallery", v)
		return
	}
	fromated := foramt_galerry_post_links(fromated_blogs, galerry.(string))

	index: os.Handle
	err = os.remove("index.html")
	if err != nil {
		fmt.println(err)
	}
	if index, err = os.open("index.html", os.O_RDWR | os.O_CREATE, 0o666); err == nil {
		fmt.println(os.write_string(index, fromated))
	}
}

format_html :: proc(formater: HtmlFormater, template, data: string) -> string {
	return formater(template, data)
}

fromat_blog_post :: proc(template, data: string) -> string {
	lines := strings.split(data, "\n")
	html := cr.markdown_to_html_from_string(data, {.Unsafe})
	res, _ := strings.replace(template, POST_CONTENT_FMT_REPLACE_STR, html, 1)
	return res
}

create_index_postst_links :: proc(blog_posts: BlogPosts) -> string {
	buf: [dynamic]string
	for blog_post, data in blog_posts {
		dir_path := strings.join({OUTPUT_DIR, blog_post}, "")
		html_extented := strings.join({strings.trim_right(data.posts[0].name, ".md"), ".html"}, "")
		post_path := strings.join({dir_path, html_extented}, "/")
		href_tag := strings.join({"href=\"", post_path, "\""}, "")
		append(&buf, apply_html_tag("a", blog_post, href_tag))
		append(&buf, "<br>")
		append(&buf, strings.join({"<iframe src=\"", post_path, "\"></iframe>"}, ""))
		append(&buf, "<br>")
	}
	return strings.join(buf[:], "\n")
}

create_blog_header :: proc(posts: []PostPage) -> string {
	buf: [dynamic]string
	for post, idx in posts {
		html_extented := strings.join({strings.trim_right(post.name, ".md"), ".html"}, "")
		idx_buff: [4]byte
		href_tag := strings.join({"href=\"", html_extented, "\""}, "")
		append(&buf, apply_html_tag("a", strconv.itoa(idx_buff[:], idx), href_tag))
	}
	return strings.join(buf[:], " ")
}

format_html_fn :: proc($T: string) -> HtmlFormater {
	fn := proc(template, data: string) -> string {
		res, _ := strings.replace(template, T, data, 1)
		return res
	}
	return fn
}

apply_html_tag :: proc(tag: string, data: string, options: string = "") -> string {
	tag_suffix := strings.join({"<", tag, " ", options, ">"}, "")
	tag_postfix := strings.join({"</", tag, ">"}, "")
	res := strings.join({tag_suffix, data, tag_postfix}, "")
	return res
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
			os.write_string(post_fd, post.formated) or_return
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

create_galery_images :: proc() -> Result(string, os.Error) {
	dir_fd := os.open(GALLERY_DIR_PATH) or_return
	file_info := os.read_dir(dir_fd, 0) or_return
	buf: [dynamic]string
	append(&buf, "<div class=\"row\">")

	size := max(GALLERY_MIN_COLLUMS, len(file_info) / 4)
	j: int
	for i := 0; i < len(file_info); i += size {
		j += size
		if j > len(file_info) {
			j = len(file_info)
		}
		column := file_info[i:j]
		append(&buf, "<div class=\"column\">")
		for img in column {
			full_path := strings.join({GALLERY_DIR_PATH, "/", img.name}, "")
			append(&buf, strings.join({"<img src=\"", full_path, "\">"}, ""))
		}
		append(&buf, "</div>")
	}
	append(&buf, "</div>")
	return strings.join(buf[:], "")
}

max :: proc(a, b: $T) -> T {
	return a if a >= b else b
}
