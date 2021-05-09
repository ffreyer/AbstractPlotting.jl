struct MarkupString <: AbstractString
    input::String
    output::String
    offsets::Vector{Vec2f0}
    textsizes::Vector{Float32}
end

function MarkupString(str::String)
    input = str
    char_buffer = Char[]
    states = Int8[]
    
    in_group = false
    state = 0
    escaping = false
    
    for c in str
        if escaping
            push!(char_buffer, c)
            push!(states, state)
        elseif c == '\\'
            escaping = true
        elseif c == '^' && state == 0
            state = 1
        elseif c == '_' && state == 0
            state = -1
        elseif c == '{' && !in_group
            in_group = true
        elseif c == '}' && in_group
            in_group = false
        elseif in_group
            push!(char_buffer, c)
            push!(states, state)
        else
            push!(char_buffer, c)
            push!(states, state)
            state = 0
        end
    end
    
    MarkupString(
        input, join(char_buffer),
        [(Vec2f0(0, -0.5), Vec2f0(0), Vec2f0(0, 0.5))[state+2] for state in states],
        [(0.7f0, 1f0, 0.7f0)[state+2] for state in states]
    )
end

macro markup_str(str)
    MarkupString(str)
end

function Base.show(io::IO, s::MarkupString)
    print(io, "MarkupString(")
    show(io, s.input)
    print(io, ")")
end


function plot!(p::Text{Tuple{MarkupString}})
    str = map(x -> x.output, p[1])
    textsize = map((x, ts) -> ts .* x.textsizes, p[1], p.textsize)
    offset = map(p[1], p.textsize, p.offset) do x, ts, o
        offsets = ts .* x.offsets
        if o isa Vector
            return offsets .+ o
        else
            map!(a -> a .+ to_ndim(Point2f0, o, 0), offsets, offsets)
            return offsets
        end
    end
    attr = merge(Attributes(textsize = textsize, offset = offset), p.attributes)
    text!(p, str; attr...)
end

function plot!(p::Text{Tuple{Vector{MarkupString}}})
    str = map(markups -> [x.output for x in markups], p[1])
    textsize = map(p[1], p.textsize) do markups, ts
        if ts isa Vector
            return map((x, ts) -> ts .* x.textsizes, markups, ts)
        else
            return map(x -> ts * x.textsizes, markups)
        end
    end
    offset = map(p[1], p.textsize, p.offset) do markups, ts, o
        if ts isa Vector
            offsets = map((x, ts) -> ts .* x.offsets, markups, ts)
        else
            offsets = map(x -> ts * x.offsets, markups)
        end
        if o isa Vector{Vector}
            map!(offsets, offsets, o) do offsets, o
                [a .+ to_ndim(Vec2f0, b, 0) for (a, b) in zip(offsets, o)]
            end
        elseif o isa Vector
            map!(offsets, offsets, o) do offsets, o
                [a .+ to_ndim(Vec2f0, o, 0) for a in offsets]
            end
        else
            map!(offsets, offsets) do offsets
                [a .+ to_ndim(Vec2f0, o, 0) for a in offsets]
            end
        end
        return offsets
    end
    attr = merge(Attributes(textsize = textsize, offset = offset), p.attributes)
    text!(p, str; attr...)
end

function plot!(p::Text{<:Tuple{<: AbstractArray{ <: Tuple{MarkupString, <: Point}}}})
    markup_strings = map(p[1]) do combined
        [markup for (markup, pos) in combined]
    end
    positions = map(p[1]) do combined
        [to_ndim(Point3f0, pos, 0) for (markup, pos) in combined]
    end
    attr = p.attributes
    pop!(attr, :position)
    text!(p, markup_strings; position = positions, attr...)
end

function convert_arguments(::Type{<: Text}, x::MarkupString)
    (x,)
end
