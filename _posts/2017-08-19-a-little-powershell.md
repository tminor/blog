---
layout: post
title: A PowerShell script involving cyclists.
date: 2017-08-19 01:09:37
disqus: y
---

## A little background

I've been involved in a Fantasy Football league for the past few years, and each year the draft order has been decided in some inventive way. This year, an announcement was made that read as such:

> The 2017 Canada Games Road Cycling - Male Criterium. It is truly an event that no one here will have an advantage in understanding. There are 45 bikers and everyone in the League will choose three. The HIGHEST FINISHER of your three will be your *official* choice. Everyone's official choice will decide the draft order.

Given that I've not had access to my homelab recently, I thought this might be a good opportunity to be productive and practice some scripting.

---

## Beggining with a rough idea

The members of The League were provided with enough resources to locate the race participants; after finding the list I copied the text directly from the source page and stuck it in a text file that ended up looking something like this:

```
Alexander Amiri         Cycling
[British Columbia]  Brendan Armstrong   Cycling
[Quebec]  Raphaël Auclair       Cycling
[Ontario]  Tim Austen   Cycling
[Saskatchewan]  Caleb Bender    Cycling
[Manitoba]  Willem Boersma      Cycling
[Prince Edward Island]  André Boudreau  Cycling
[Saskatchewan]  Lukas Conly     Cycling
[New Brunswick]  Alex Cormier   Cycling
[Quebec]  Pier-André Côté       Cycling
. . .
```

Not being familiar with cycling, my first step was Googling; searching yielded a pretty decent result with [Pro Cycling Stats](http://www.procyclingstats.com/). I tested the site by using some of the names as inputs to the site's search function and found that a direct match for a name yielded that rider's race results in a nicely formatted chart. I initially considered calculating average finishing position for each rider but quickly discarded the idea upon realizing that each race had a decently large variation in its number of participants. Ultimately, I envisioned taking the list as an input and producing as an output a ranked list of the race participants.

## Problem solving

I needed a way to effeciently determine which riders were better than others. After a bit more exploration, I found that the site features a nifty "head-to-head" application/script that can compare any number of riders using a variety of statistics. Why devise a way to compare riders when you could just take advantage of something that already exists? It's hard to know exactly what the application does in calculating each rider's score, but I can safely assume that it's more effective than anything I could devise.

After a bit of experimentation, I noticed that the application appears to use PHP's `parse_url()` (or something similar) to accept values via the URI:

```
http://www.procyclingstats.com/rider.php?id=Tim_Ariesen&c=6&ids=170986,126972
```

I recognized this pattern from my earlier testing; a rider's page uses a URI that conforms to the following scheme:

```
http://www.procyclingstats.com/rider.php?id=170986
```

So I needed a way to collect riders' IDs and feed them to the "head-to-head" application. Thankfully, the search function also uses a very predictable URI scheme:

```
http://www.procyclingstats.com/search.php?term=tim+ariesen&searchf=Search
```

## Taking names

Using the list of names created earlier, we can generate an input for some kind of function that interacts with the search application. Before we get to that, we need to clean up the list so that each name can be cleanly passed to `search.php`.


{% highlight powershell %}
# File containing the names of race participants
$File = "C:\Users\user\Desktop\cycles.txt"

# Get rider names
$Riders = @()
$Riders = Get-Content -Path $File
$Riders = $Riders -replace '(?=\[).*?(?=\])\]', ''
$Riders = $Riders -replace 'Cycling', ''
$Riders = $Riders.trim()
$Riders = $Riders -replace ' ', '+'
{% endhighlight %}


We begin by creating a variable for the text file containing the rider names. We then create another variable called `$Riders` and tell PowerShell that we want it to be an empty array by using an empty array subexpression `@()`. Generally, PowerShell is very good at guessing data types but sometimes it doesn't get it right!

We then use the `Get-Content` cmdlet to retrieve text from `cycles.txt` and store it as the value of `$Riders`. Next, we apply a series of regular expressions using the `-replace` operator; the syntax is as follows:

```
"operand string" -replace 'match pattern', 'replace pattern'
```

The match pattern uses regular expressions; our first regex replaces anything delimited by an opening and closing square bracket with an empty string; our second regex also replaces anything matching `Cycling` with an empty string. Next, we use the `.Trim()` method to rid each line of leading and trailing white space. Lastly, we replace any remaining spaces with a `+`. After transformation, each line should conform to the following pattern:

```
firstname+lastname
```

## Enter Invoke-WebRequest

We now have all of the input we need to interact with Pro Cycling Stats's `search.php`; we can use a handy cmdlet called `Invoke-WebRequest` to handle the interaction part. Running `Get-Help Invoke-WebRequest` returns:

```
DESCRIPTION
    The Invoke-WebRequest cmdlet sends HTTP, HTTPS, FTP, and FILE requests to a web page or web service. It parses the response and returns collections of forms, links, images, and other significant HTML elements.
```

Wow, great!

Something important to understand about PowerShell is that it is [object-oriented](https://powertoe.wordpress.com/2014/04/26/you-know-powershell-is-an-object-oriented-language-right/). With that in mind, we can assume that if we execute `Invoke-WebRequest` as a subexpression, we can access its properties somehow. PowerShell uses `.` as a property dereferencing operator; let's use `Invoke-WebRequest` to examine this behavior:

{% highlight powershell %}
Invoke-WebRequest -Uri google.com | Format-List
{% endhighlight %}

The outpute should look something like:

```
StatusCode        : 200
StatusDescription : OK
Content           : <!doctype html><html itemscope="" itemtype="http://schema.org/WebPage" lang="en"><head><meta content="Search the world's information, including webpages, images, videos and more. Google has many speci...
RawContent        : HTTP/1.1 200 OK
                    X-XSS-Protection: 1; mode=block
                    X-Frame-Options: SAMEORIGIN
                    Vary: Accept-Encoding
                    Transfer-Encoding: chunked
                    Accept-Ranges: none
                    Cache-Control: private, max-age=0
                    Content-Type: ...
Forms             : {f}
. . .
```

We can see that one of the properties is `Links:`, so we can look more closely by running:

{% highlight powershell %}
Invoke-WebRequest -Uri google.com | Select-Object Links | Format-List
{% endhighlight %}

The output should be several lines of attribute-value pairs. Another cool thing about PowerShell (and maybe this is a cool thing about `Invoke-WebRequest` specifically) is that you can access the values of these attributes in the same way you'd do it with an object (using subexpressions and the `.` operator mentioned earlier):

{% highlight powershell %}
(Invoke-WebRequest -Uri google.com).Links.outerHTML
{% endhighlight %}

## Collecting IDs

Using the strategy outlined above, we might be able to devise some way to corral links to each rider's page. If we can do this, we can probably extract their ID as well.

Let's go back to accessing the properties of our web request; with some knowledge of HTML, we can deduce that if we collect `href=` values, we can probably find the links that contain our desired ID numbers. Let's take a look at some example output by running the following:

{% highlight powershell %}
(Invoke-WebRequest -Uri "http://www.procyclingstats.com/search.php?term=tim+ariesen&searchf=Search").Links.Href
{% endhighlight %}

And the output:

```
info.php?action=1502217039
index.php?cookie=1&amp;SetCookieConsent=1
http://www.procyclingstats.com/
https://www.facebook.com/ProCyclingStats
https://www.youtube.com/channel/UCpu35hcS3_1IlEb80aJem7Q
https://twitter.com/ProCyclingStats
http://www.procyclingstats.com/contact.php
. . .
?goto=rider&amp;id=170986&amp;rnk=0&amp;type=1&amp;title=search_page&amp;term=tim ariesen
race.php?id=171047
race.php?id=171088
race.php?id=171127
race.php?id=170996
race.php?id=171007
race.php?id=171015
. . .
```

We can see that our output contains quite a few references to ID numbers that identify specific races and other non-rider entities. How do we determine which IDs belong to the riders we initially passed to `search.php`? First, let's corral the links we need.

Using our prepared rider names, we can iterate over them using a `foreach` loop to execute some commands. So for each `$Rider`, we want all `href=` attributes and their corresponding values from the `Links:` property of each web request. That would look something like:

{% highlight powershell %}
foreach ($Rider in $Riders) {
    $(Invoke-WebRequest -Uri ("http://www.procyclingstats.com/search.php?term=$Rider&searchf=Search")).Links.Href | `
    Out-File -FilePath "C:\Users\user\Desktop\results.txt" -Append
}
{% endhighlight %}

Notice that we've used the `$Rider` variable to pass our rider names to `search.php` and then piped it out to a file, appending each line along the way. This leaves us with a giant file containing every possible link for every rider fed to `search.php`. Now we can begin to identify a salient characteristic that can be used to isolate each desired URI. With a little intuition, we can deduce that the lines we probably want contain a specific pattern: `rnk=0`. How do we find and store the lines we want?

Let's try starting with a variable and again tell PowerShell that we'd like it to be an empty array.

{% highlight powershell %}
$Results = @()
{% endhighlight %}

Using the previously generated `results.txt` file, we can get its content and select lines by matching against a regular expression:

{% highlight powershell %}
$Results = Get-Content -Path C:\Users\user\Desktop\results.txt | Select-String -Pattern '.*(\brnk=0\b).*' | Select-Object -ExpandProperty line
{% endhighlight %}

Next, we need to whittle down our results so that we are left with the value of each `id=` attribute; once again, we do this by using regular expressions. This time, however, we use a regular expression object!

We do this by creating a variable as we normally would but tell PowerShell that this particular object is a regular expression by type casting it as such:

{% highlight powershell %}
[regex]$regex = 'id=[0-9]*'
{% endhighlight %}

We can now take advantage of this object's `.Match()` method:

{% highlight powershell %}
$Results = $regex.Matches($Results) | ForEach-Object {$_.Value}
{% endhighlight %}

We mustn't forget that our matches are also objects, so we pipe each match to `ForEach-Object` and use an [automatic variable](https://docs.microsoft.com/en-us/powershell/module/Microsoft.PowerShell.Core/about_Automatic_Variables?view=powershell-5.1); in our case, we use `$_` to capture each matches `.Value` property:

> [$_] contains the current object in the pipeline object. You can use this variable in commands that perform an action on every object or on selected objects in a pipeline.

Now we can begin to isolate only the ID numbers and concatenate them to create a single string:

{% highlight powershell %}
$Results = $Results -replace 'id=', ''
$IDString = $Results -join ','
{% endhighlight %}

The first line should look familiar; the second uses the `-join` operator to perform concatenation, using a `,` as a delimiter for each ID number.

## Create your own object

With our newly created ID string, we can now interact with `rider.php`'s "head-to-head" function.

{% highlight powershell %}
$WebRequest = Invoke-WebRequest -Uri "http://www.procyclingstats.com/rider.php?id=Tim_Ariesen&c=6&ids=$IDString"
{% endhighlight %}

We also need to create another empty array:

{% highlight powershell %}
$RiderObjects = @()
{% endhighlight %}

We'll cover that in a little bit.

With that out of the way, we can begin to concoct a way to handle the content retrieved by `$WebRequest`. By examining the source of the "head-to-head" page, we notice that each rider's name and respective score are contained within a `<div>` HTML element. Based on our experience so far, we know that we can probably capture the values we want using regular expressions. So here's the regular expression we'll use:

```
<div style="font: bold 20px tahoma, arial, Century Gothic; letter-spacing: -1px; ">([a-zA-z]*)<br \/>([a-zA-z]*)<\/div><div style="font: bold 18px tahoma, arial, Century Gothic; letter-spacing: -1px; padding: 9px 0; color: #e00; ">([0-9]*\.[0-9]*%)<\/div>
```

With the above regular expression, we use three capture groups: first name, last name, and score. We can use these values as properties in a custom object. Here's how we'd do that:

{% highlight powershell %}
$regex.Matches($WebRequest.Content) | ForEach-Object{
    $objRider = New-Object psobject -Property @{
        Name  = "$($_.Groups[1].Value) $($_.Groups[2].value)"
        Score = ([decimal]$($_.Groups[3].Value).Replace('%',''))
    }
    $Global:RiderObjects += $objRider
}
{% endhighlight %}

First, we start with our `$regex` object and use the `.Matches()` method using `$WebRequest`'s `Content` property (which happens to be raw HTML) as input. Next, we pipe the output to a `ForEach-Object` loop that creates a new object called `$objRider` for each match. Again, we use the `$_` automatic variable and the `.` property dereference operator to access each capture group. The "Name" property is straightforward; we take capture groups `1` and `2` and concatenate them into one string. For the "Score" property, we need to perform some manipulation so that we can properly sort them numerically (otherwise, PowerShell would assume that the percentage number is a string and sort it alphabetically). We do this by type casting the value for "Score" as `[decimal]`, call the `.Replace()` method, replacing `%` with an empty string, all within a subexpression that returns the resultant value as a float (or decimal).

Once we've successfully created our object, we use the assignment by addition operator `+=` to append the object to an empty array, `$Global:RiderObjects`. We tell PowerShell that this variable should be accessible in the global scope so that we can use it outside the scope of the `ForEach-Object` loop.

With our newly created objects, we can now manipulate the results as we would any other object.

{% highlight powershell %}
$RiderObjects | Sort-Object Score -Descending
{% endhighlight %}

Output:

```
Name              Score
----              -----
Joseph Didden      13.0
Tim Ariesen         6.8
Nicolas Zukowsky    5.2
Kurt Penno          2.1
Jordann Jones       1.2
Willem Boersma      0.9
```

---

## Final thoughts

One thing I didn't control for was false positives; the person who scored the highest, for example, only participated in one race that took place in 1939. Another example is that Tim Ariesen isn't participating in the race we care about. I have some ideas as to how I might account for such aberrations, but it was a fun exercise nevertheless. As an outro, here's the script in aggregate:

{% highlight powershell %}
# File containing the names of race participants
$File = "C:\Users\tminor\Desktop\cycles.txt"

# Get rider names
$Riders = @()
$Riders = Get-Content -Path $File
$Riders = $Riders -replace '(?=\[).*?(?=\])\]', ''
$Riders = $Riders -replace 'Cycling', ''
$Riders = $Riders.trim()
$Riders = $Riders -replace ' ', '+'

# After some manipulation, use rider names to search www.procyclingstats.com
# Store all output in a file
foreach ($Rider in $Riders) {
    $(Invoke-WebRequest -Uri ("http://www.procyclingstats.com/search.php?term=$Rider&searchf=Search")).Links.Href | `
    Out-File -FilePath "C:\Users\tminor\Desktop\results.txt" -Append
}

# Read the file generated above and store all matching lines in an array
$Results = @()
$Results = Get-Content -Path C:\Users\tminor\Desktop\results.txt | Select-String -Pattern '.*(\brnk=0\b).*' | Select-Object -ExpandProperty line

# Determine rider IDs by extracting them from URIs with an ID regex
[regex]$Regex = 'id=[0-9]*'
$Results = $regex.Matches($Results) | ForEach-Object {$_.Value}

# Store only the ID number
$Results = $Results -replace 'id=', ''

# Concat all ID numbers to use in URI to compare riders
$IDString = $Results -join ','
$WebRequest = Invoke-WebRequest -Uri "http://www.procyclingstats.com/rider.php?id=Chris MacLeod&c=6&ids=$IDString"

# Initialize new array for custom object
$RiderObjects = @()

# Use regex to capture all relevant data
[regex]$Regex = '<div style="font: bold 20px tahoma, arial, Century Gothic; letter-spacing: -1px; ">([a-zA-z]*)<br \/>([a-zA-z]*)<\/div><div style="font: bold 18px tahoma, arial, Century Gothic; letter-spacing: -1px; padding: 9px 0; color: #e00; ">([0-9]*\.[0-9]*%)<\/div>'

# Iterate over regex matches, creating a custom object 
# For each match, add each capture group to its respective object attribute
$Regex.Matches($WebRequest.Content) | ForEach-Object{
    $ObjRider = New-Object psobject -Property @{
        Name  = "$($_.Groups[1].Value) $($_.Groups[2].value)"
        Score = ([decimal]$($_.Groups[3].Value).Replace('%',''))
    }
    $Global:RiderObjects += $ObjRider
}

# Sort the custom object by score in descending order
$RiderObjects | Sort-Object Score -Descending
{% endhighlight %}

**UPDATE:** My final draft position is second from last. I experienced a glimmer of hope when the time trials performed by the same group of riders yielded a first place finish for me, but alas, the taste of victory is bitter-sweet.