
import Website.Blog (skeleton)
import Window

port title : String
port title = "Making Pong"

main = lift (skeleton content) Window.width

content w = width (min 600 w) [markdown|

<style type="text/css">
p { text-align: justify }
pre { background-color: white;
      padding: 10px;
      border: 1px solid rgb(216, 221, 225);
      border-radius: 4px;
}
code > span.kw { color: #268BD2; }
code > span.dt { color: #268BD2; }
code > span.dv, code > span.bn, code > span.fl { color: #D33682; }
code > span.ch { color: #DC322F; }
code > span.st { color: #2AA198; }
code > span.co { color: #93A1A1; }
code > span.ot { color: #A57800; }
code > span.al { color: #CB4B16; font-weight: bold; }
code > span.fu { color: #268BD2; }
code > span.re { }
code > span.er { color: #D30102; font-weight: bold; }
</style>

<div style="font-family: futura, 'century gothic', 'twentieth century', calibri, verdana, helvetica, arial; text-align: center; font-size: 4em;">Making Pong</div>

This post has two major goals:

 1. Get you thinking about [Functional Reactive
    Programming](/learn/What-is-FRP.elm) (FRP) for games.
 2. Teach you how to make games with Elm.

In this post we will be looking into [Pong in Elm](/edit/examples/Intermediate/Pong.elm):
a functional game written in Elm, playable in any modern browser.

### Functional Game Design

Making games is historically a very imperative undertaking, so it has long
missed the benefits of purely functional programming. FRP makes it possible
to program rich user interactions without resorting to traditional imperative
idioms.

By the end of this post we will have written an entire GUI/game without any
imperative code. No global mutable state, no flipping pixels, no destructive
updates. In fact, Elm disallows all of these things at the language level.
So good design and safe coding practices are a requirement, not just
self-inforced suggestions.

Imperative programs allow you to reach into objects and data structures
whenever you want, so it is not a huge deal if your code is somewhat
disorganized. With functional game design, we must be more careful about how
our programs are structured. In fact in Elm, all games will share the same
underlying structure.

The structure of Elm games breaks into three major parts: modeling the game,
updating the game, and viewing the game. It may be helpful to think of it as a
functional variation on the Model-View-Controller paradigm.

To make this more concrete, lets see how Pong needs to be structured:

 1. **Model:** First we need to define Pong. We do this by modelling Pong with
    simple data structures. We need two categories of model:

      * Inputs to the game. For Pong, this is keyboard input from users and
        clock-ticks from the frame rate manager.

      * A model of the game itself: paddles, ball, score, etc. Without a model
        of the game we would have nothing to update or display! These models
        are the basis for the next two sections. They hold all of the
        information about Pong that we will need.

 2. **Update:** When new inputs come in, we need to update the game. Without
    updates, this version of Pong would be very very boring! This section
    defines a number of 'step functions' that step the game forward based on
    our inputs. By separating this from the model and display code, we can
    change how the game works (how it steps forward) without changing anything
    else: the underlying model and the display code need not be touched.

 3. **View:** Finally, we need a display function that defines the user's view of
    the game. This code is completely separate from the game logic, so it can
    be modified without affecting any other part of the program. We can also
    define many different views of the same underlying model. In Pong there is
    not much need for this, but as your model becomes more complex this may be
    very useful!

If you would like to make a game or larger application in Elm, use this
structure! I provide both [the source code for Pong][src] and [an empty
skeleton for game creation][skeleton] which can both be a starting point for
playing around with your own ideas.

 [src]: https://github.com/evancz/elm-lang.org/blob/master/public/examples/Intermediate/Pong.elm
 [skeleton]: https://github.com/evancz/elm-lang.org/blob/master/public/examples/Intermediate/GameSkeleton.elm

Let&rsquo;s get into the code!

## Inputs

This game has two primary inputs: the passage of time and key presses.
With the keyboard, we to keep track of:

  * SPACE &mdash; to pause and unpause the game.
  * w/s &mdash; whether paddle *one* is moving up or down.
  * &uarr;/&darr; &mdash; whether paddle *two* is moving up or down.

We can represent the state of the SPACE key with a boolean value. Up and down
can be represented by an integer in { -1, 0, 1 }. So to represent the game
like this:

```haskell
type Input = { space:Bool, paddle1:Int, paddle2:Int, delta:Time }
```

From here we will actually define these inputs. To keep track of the passage of
time, we define `delta` using the `fps` function. The `fps` takes a target
frames-per-second and gives a sequence of time deltas that gets as close to the
desired FPS as possible. If the browser can not keep up, the time deltas will
slow down gracefully.

```haskell
delta : Signal Time
delta = inSeconds <~ fps 35
```

Now we put that together with the [keyboard][] inputs to make a signal representing
all inputs. Notice that we sample on time deltas so that keyboard events do not
cause extra updates.

 [keyboard]: http://library.elm-lang.org/catalog/evancz-Elm/0.11/Keyboard

```haskell
input : Signal Input
input = sampleOn delta <| Input <~ Keyboard.space
                                 ~ lift .y Keyboard.wasd
                                 ~ lift .y Keyboard.arrows
                                 ~ delta
```

## Model

Here we will define the data structures that will be used throughout the rest
of the program. This is the foundation of our game, so changes here will likely
cause changes everywhere else.

These models are a rough specification for your game. They force you to ask:
Which features do I want? What information do I need for those features? How
do I represent that information? Once you have figured out the core information
needed for your game, you have already done a lot of planning about how
everything else will work.

Do not be afraid to spend a lot of time thinking about this!

### Modelling Pong / a State Machine

Pong has two obvious components: the ball and two paddles.

```haskell
(gameWidth,gameHeight) = (600,400)
(halfWidth,halfHeight) = (300,200)

data State = Play | Pause

type Ball = { x:Float, y:Float, vx:Float vy:Float }

type Player = { x:Float, y:Float, vx:Float, vy:Float, score:Int }

type Game = { state:State, ball:Ball, player1:Player, player2:Player }

player : Float -> Player
player x = { x=x, y=0, vx=0, vy=0, score=0 }

defaultGame : Game
defaultGame =
  { state   = Pause
  , ball    = { x=0, y=0, vx=200, vy=200 }
  , player1 = player (20-halfWidth)
  , player2 = player (halfWidth-20)
  }
```

## Update

```haskell
stepObj t ({x,y,vx,vy} as obj) =
    { obj | x <- x + vx*t, y <- y + vy*t }

near k c n = n >= k-c && n <= k+c
within ball paddle = (ball.x |> near paddle.x 8)
                  && (ball.y |> near paddle.y 20)

stepV v lowerCollision upperCollision =
  if | lowerCollision -> abs v
     | upperCollision -> 0 - abs v
     | otherwise      -> v

stepBall : Time -> Ball -> Player -> Player -> Ball
stepBall t ({x,y,vx,vy} as ball) p1 p2 =
  if not (ball.x |> near 0 halfWidth)
  then { ball | x <- 0, y <- 0 }
  else stepObj t { ball | vx <- stepV vx (ball `within` p1) (ball `within` p2)
                        , vy <- stepV vy (y < 7-halfHeight) (y > halfHeight-7)
                 }

stepPlyr : Time -> Int -> Int -> Player -> Player
stepPlyr t dir points player =
  let player1 = stepObj  t { player | vy <- toFloat dir * 200 }
  in  { player1 | y <- clamp (22-halfHeight) (halfHeight-22) player1.y
                , score <- player.score + points }

stepGame : Input -> Game -> Game
stepGame {space,dirL,dirR,delta} ({state,ball,player1,player2} as game) =
  let scoreL : Int
      scoreL = if ball.x >  halfWidth then 1 else 0
      scoreR = if ball.x < -halfWidth then 1 else 0
  in  {game| state   <- if | space            -> Play
                           | scoreL /= scoreR -> Pause
                           | otherwise        -> state
           , ball    <- if state == Pause then ball else
                            stepBall delta ball player1 player2
           , player1 <- stepPlyr delta dirL scoreL player1
           , player2 <- stepPlyr delta dirR scoreR player2 }

gameState = foldp stepGame defaultGame input
```

## View

```haskell
display : (Int,Int) -> Game -> Element
display (w,h) {state,ball,player1,player2} =
  let scores : Element
      scores = txt (Text.height 50) <|
               show player1.score ++ "  " ++ show player2.score
  in 
      container w h middle <| collage gameWidth gameHeight
       [ rect gameWidth gameHeight |> filled pongGreen
       , oval 15 15 |> make ball
       , rect 10 40 |> make player1
       , rect 10 40 |> make player2
       , toForm scores |> move (0, gameHeight/2 - 40)
       , toForm (if state == Play then spacer 1 1 else txt id msg)
           |> move (0, 40 - gameHeight/2)
       ]

-- helper values and functions
pongGreen = rgb 60 100 60
textGreen = rgb 160 200 160
txt f = text . f . monospace . Text.color textGreen . toText
msg = "SPACE to start, WS and &uarr;&darr; to move"

-- turn any object with a position into a white form
make : { a | x:Float, y:Float } -> Shape -> Form
make obj shape = shape |> filled white
                       |> move (obj.x,obj.y)
```

```haskell
main = lift2 display Window.dimensions gameState
```

And that is it! [Pong in Elm](/edit/examples/Intermediate/Pong.elm)

## Post Script

### Learn by Doing: Programming Challenges

If you want to learn more about making games in Elm, try tackling some of
these challenges:

 * Make the Pong field look nicer. Add a line (or dotted line) at mid-field.

 * Add the ability to pause the game during game play.

 * Add the ability to reset the game (besides refreshing the page!)

 * Make ball collisions more complicated. Possiblities:

     * When the ball hits the corner of a paddle, it changes direction.

     * If the ball hits a moving paddle, it adds spin to the ball, making it
       rebound in a different direction.

 * Add a second ball to the game.

 * Write a simple AI for a paddle. A simple strategy is to always put the
   paddle at the same y height as the ball, but this is not very fun to play
   against. Maybe try an AI that is not so smart to make things more
   interesting.

### Further Reading

If you want to read more about FRP for games, see [this paper][afrp]. Note that
it is specific to Arrowized FRP, which is supported by Elm&rsquo;s
[Automaton][automaton] library.

 [afrp]: http://haskell.cs.yale.edu/wp-content/uploads/2011/01/yampa-arcade.pdf
 [automaton]: http://library.elm-lang.org/catalog/evancz-automaton/0.1.0.1

|]