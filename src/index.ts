const app = document.getElementById("app");

interface WatchList {
	items: WatchItem[]
}

interface WatchItem {
	title: string,
	poster_url: string,
	my_anime_list_link: string
	toughts: string
}


function main() {
	fetchJSONData(generate_watch_list)
}

function generate_watch_list(data: WatchList) {
	const outter_div = document.createElement("div")
	const div = document.createElement("div")
	div.className = "watch_list"
	const title = document.createElement("h1")
	title.textContent = "Currently Watching"
	outter_div.append(title)
	outter_div.append(div)
	const items = data.items
	for (const item of items) {
		div.append(generate_watch_item(item))
	}
	app?.append(outter_div)
}

function generate_watch_item(item: WatchItem): HTMLElement {
	const div = document.createElement("div")
	div.className = "watch_item"
	const a = document.createElement("a")
	a.href = item.my_anime_list_link
	a.target = "_blank"
	const title = document.createElement("h2")
	title.textContent = item.title
	title.className = "watch_item_title"
	const img_text_div = document.createElement("div")
	img_text_div.className = "watch_item_img_text_div"
	a.append(title)
	const img = document.createElement("img")
	img.src = item.poster_url
	img_text_div.append(img)
	const toughts = document.createElement("p")
	toughts.textContent = item.toughts
	img_text_div.append(toughts)
	a.append(img_text_div)
	div.append(a)
	return div
}

function fetchJSONData(fn: Function) {
	fetch('https://horry-portier.neocities.org/watch_list.json')
		.then(response => {
			if (!response.ok) {
				throw new Error(`HTTP error! Status: ${response.status}`);
			}
			return response.json();
		})
		.then(data => fn(data))
		.catch(error => console.error('Failed to fetch data:', error));
}
main()
